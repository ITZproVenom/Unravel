import Foundation

final class SecurityScopedAccess {
    private let accessed: [URL]

    init(urls: [URL]) throws {
        var granted: [URL] = []
        do {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    throw ArchiveError.permissionDenied
                }
                granted.append(url)
            }
            accessed = granted
        } catch {
            granted.forEach { $0.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    deinit { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
}

struct ArchiveSnapshot {
    let set: VolumeSet
    let entries: [ArchiveEntry]
    let requiresPassword: Bool
}

struct ArchiveService {
    func load(set: VolumeSet, password: String?, access: SecurityScopedAccess) throws -> ArchiveSnapshot {
        _ = access
        let archive = try UNRArchive(url: set.firstVolume, password: password)
        if archive.hasMultipleVolumes && set.volumes.count < 2 {
            throw ArchiveError.missingVolumes("This is only the first volume of a multipart RAR. The remaining volumes are required to reconstruct the original complete files.")
        }
        let information = try archive.listEntries()
        var entries: [ArchiveEntry] = []
        var seen: [String: String] = [:]
        var files: Set<String> = []
        var directories: Set<String> = []
        for info in information {
            let safe = try SafeArchivePath(info.filename)
            let key = safe.relativePath.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            if let previous = seen[key] {
                if info.isDirectory && previous == safe.relativePath { continue }
                throw ArchiveError.duplicatePath(safe.relativePath)
            }
            seen[key] = safe.relativePath
            let parts = safe.relativePath.split(separator: "/").map(String.init)
            for index in 1..<parts.count {
                directories.insert(parts.prefix(index).joined(separator: "/").folding(options: .caseInsensitive, locale: nil))
            }
            if info.isDirectory { directories.insert(key) } else { files.insert(key) }
            entries.append(ArchiveEntry(sourceName: info.filename, path: safe.relativePath,
                                        name: safe.lastComponent, uncompressedSize: info.uncompressedSize,
                                        compressedSize: info.compressedSize, modificationDate: info.timestamp,
                                        isDirectory: info.isDirectory, isEncrypted: info.isEncryptedWithPassword))
        }
        for file in files where directories.contains(file) { throw ArchiveError.duplicatePath(file) }
        return ArchiveSnapshot(set: set, entries: entries,
                               requiresPassword: archive.isPasswordProtected || entries.contains(where: \.isEncrypted))
    }

    func extract(snapshot: ArchiveSnapshot, selected: Set<String>, password: String?,
                 access: SecurityScopedAccess, progress: Progress,
                 onFileStart: (String) -> Void) throws -> ExtractionResult {
        _ = access
        let chosen = snapshot.entries.filter { selected.contains($0.id) }
        let fileEntries = chosen.filter { !$0.isDirectory }
        guard !chosen.isEmpty else { throw ArchiveError.invalidSelection("Select at least one file or folder to extract.") }
        let total = fileEntries.reduce(Int64(0)) { $0 + max($1.uncompressedSize, 0) }
        if let capacity = try? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage, capacity >= 0, total > capacity {
            throw ArchiveError.diskFull
        }

        let manager = FileManager.default
        let workspace = manager.temporaryDirectory.appendingPathComponent("Unravel-" + UUID().uuidString, isDirectory: true)
        let output = workspace.appendingPathComponent(snapshot.set.title + " Extracted", isDirectory: true)
        try manager.createDirectory(at: output, withIntermediateDirectories: true)
        do {
            let archive = try UNRArchive(url: snapshot.set.firstVolume, password: password)
            for directory in chosen.filter(\.isDirectory).sorted(by: { $0.path.count < $1.path.count }) {
                let destination = try SafeArchivePath(directory.path).url(under: output)
                try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            }
            for entry in fileEntries {
                if progress.isCancelled { throw ArchiveError.cancelled }
                onFileStart(entry.path)
                let destination = try SafeArchivePath(entry.path).url(under: output)
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                let partial = destination.deletingLastPathComponent().appendingPathComponent(".unravel-" + UUID().uuidString)
                let units = max(entry.uncompressedSize, 1)
                let child = Progress(totalUnitCount: units)
                progress.addChild(child, withPendingUnitCount: units)
                try archive.extractEntry(named: entry.sourceName, destination: partial, progress: child)
                child.completedUnitCount = child.totalUnitCount
                if manager.fileExists(atPath: destination.path) { throw ArchiveError.duplicatePath(entry.path) }
                try manager.moveItem(at: partial, to: destination)
                if let date = entry.modificationDate {
                    try? manager.setAttributes([.modificationDate: date], ofItemAtPath: destination.path)
                }
            }
            for directory in chosen.filter(\.isDirectory).sorted(by: { $0.path.count > $1.path.count }) {
                if let date = directory.modificationDate {
                    try? manager.setAttributes([.modificationDate: date], ofItemAtPath: try SafeArchivePath(directory.path).url(under: output).path)
                }
            }
            return ExtractionResult(directory: output, workspace: workspace, fileCount: fileEntries.count, byteCount: total)
        } catch {
            try? manager.removeItem(at: workspace)
            throw ArchiveError.map(error)
        }
    }

    func cleanup(_ result: ExtractionResult) {
        try? FileManager.default.removeItem(at: result.workspace)
    }
}
