import Foundation

struct VolumeSet {
    let firstVolume: URL
    let volumes: [URL]
    let accessRoots: [URL]
    let isMultipart: Bool
    let title: String

    static func resolve(selected URLs: [URL]) throws -> VolumeSet {
        guard !URLs.isEmpty else { throw ArchiveError.invalidSelection("Choose a RAR archive to open.") }
        let files = URLs.map(\.standardizedFileURL)
        guard files.allSatisfy({ !$0.hasDirectoryPath }) else {
            throw ArchiveError.invalidSelection("Choose archive files, or use Grant Containing Folder.")
        }
        guard let first = files.first(where: { isModernFirst($0) || isOldFirst($0, among: files) }) else {
            throw ArchiveError.invalidSelection("Select the first volume: name.part1.rar or name.rar. A middle volume cannot reconstruct a set by itself.")
        }
        let selected = try matchingVolumes(for: first, among: files)
        guard selected.count == files.count else {
            throw ArchiveError.invalidSelection("The selection contains unrelated files. Select only the first RAR and all volumes belonging to the same set.")
        }
        try validateSequence(selected, first: first)
        return VolumeSet(firstVolume: first, volumes: selected, accessRoots: files,
                         isMultipart: selected.count > 1, title: archiveTitle(first))
    }

    static func resolve(folder: URL) throws -> VolumeSet {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        let candidates = files.filter { isModernFirst($0) || isOldFirst($0, among: files) }
        guard candidates.count == 1, let first = candidates.first else {
            throw ArchiveError.invalidSelection(candidates.isEmpty ? "No first RAR volume was found in this folder." : "This folder contains multiple RAR sets. Use Open Archive and select the first volume plus every volume in one set.")
        }
        let volumes = try matchingVolumes(for: first, among: files)
        try validateSequence(volumes, first: first)
        return VolumeSet(firstVolume: first, volumes: volumes, accessRoots: [folder],
                         isMultipart: volumes.count > 1, title: archiveTitle(first))
    }

    private static func matchingVolumes(for first: URL, among files: [URL]) throws -> [URL] {
        let directory = first.deletingLastPathComponent().standardizedFileURL.path
        guard files.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL.path == directory }) else {
            throw ArchiveError.invalidSelection("All volumes must be in the same containing folder.")
        }
        let name = first.lastPathComponent
        if let modern = modernParts(name) {
            guard modern.index == 1 else { throw ArchiveError.invalidSelection("Open name.part1.rar, not a later part.") }
            return files.filter { file in
                guard let part = modernParts(file.lastPathComponent) else { return false }
                return part.base.caseInsensitiveCompare(modern.base) == .orderedSame
            }.sorted { modernParts($0.lastPathComponent)!.index < modernParts($1.lastPathComponent)!.index }
        }
        let base = first.deletingPathExtension().lastPathComponent
        return files.filter { file in
            if file == first { return true }
            guard file.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(base) == .orderedSame else { return false }
            return oldIndex(file) != nil
        }.sorted { (oldIndex($0) ?? -1) < (oldIndex($1) ?? -1) }
    }

    private static func validateSequence(_ volumes: [URL], first: URL) throws {
        if modernParts(first.lastPathComponent) != nil {
            let indices = volumes.compactMap { modernParts($0.lastPathComponent)?.index }
            guard indices == Array(1...indices.count) else {
                throw ArchiveError.missingVolumes("The part numbers are not continuous. A name.partN.rar volume is missing from the selection.")
            }
        } else if volumes.count > 1 {
            let indices = volumes.compactMap(oldIndex)
            guard indices == Array(0...indices.count - 1) else {
                throw ArchiveError.missingVolumes("The old-style volume numbers are not continuous. Include name.rar, name.r00, name.r01, and every following volume without gaps.")
            }
        }
    }

    private static func modernParts(_ filename: String) -> (base: String, index: Int)? {
        guard filename.lowercased().hasSuffix(".rar") else { return nil }
        let stem = filename.dropLast(4)
        guard let range = stem.range(of: ".part", options: [.caseInsensitive, .backwards]) else { return nil }
        let digits = stem[range.upperBound...]
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber), let index = Int(digits) else { return nil }
        return (String(stem[..<range.lowerBound]), index)
    }

    private static func isModernFirst(_ url: URL) -> Bool { modernParts(url.lastPathComponent)?.index == 1 }

    private static func oldIndex(_ url: URL) -> Int? {
        let ext = url.pathExtension.lowercased()
        if ext == "rar" { return 0 }
        guard ext.count == 3, ext.hasPrefix("r"), let value = Int(ext.dropFirst()), value >= 0 else { return nil }
        return value + 1
    }

    private static func isOldFirst(_ url: URL, among files: [URL]) -> Bool {
        guard url.pathExtension.lowercased() == "rar", modernParts(url.lastPathComponent) == nil else { return false }
        let base = url.deletingPathExtension().lastPathComponent
        let continuations = files.filter { $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(base) == .orderedSame && ($0.pathExtension.lowercased().hasPrefix("r") && $0.pathExtension.lowercased() != "rar") }
        return continuations.isEmpty || oldIndex(url) == 0
    }

    private static func archiveTitle(_ first: URL) -> String {
        if let modern = modernParts(first.lastPathComponent) { return modern.base }
        return first.deletingPathExtension().lastPathComponent
    }
}
