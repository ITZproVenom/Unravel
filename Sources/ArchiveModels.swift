import Foundation

struct ArchiveEntry: Identifiable, Hashable {
    let sourceName: String
    let path: String
    let name: String
    let uncompressedSize: Int64
    let compressedSize: Int64
    let modificationDate: Date?
    let isDirectory: Bool
    let isEncrypted: Bool

    var id: String { path }

    var sizeText: String {
        isDirectory ? "Folder" : ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    var dateText: String {
        guard let modificationDate else { return "Date unavailable" }
        return modificationDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ArchiveNode: Identifiable, Hashable {
    let name: String
    let path: String
    let entry: ArchiveEntry?
    var children: [ArchiveNode]?

    var id: String { path }
    var isFolder: Bool { children != nil }

    static func tree(entries: [ArchiveEntry]) -> [ArchiveNode] {
        var folders: [String: [String: ArchiveNode]] = [:]
        var files: [String: ArchiveNode] = [:]
        let sorted = entries.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        for entry in sorted where !entry.isDirectory {
            files[entry.path] = ArchiveNode(name: entry.name, path: entry.path, entry: entry, children: nil)
            let parts = entry.path.split(separator: "/").map(String.init)
            guard parts.count > 1 else { continue }
            var path = ""
            for part in parts.dropLast() {
                path = path.isEmpty ? part : path + "/" + part
                if folders[path] == nil { folders[path] = [:] }
            }
        }
        for entry in sorted where entry.isDirectory {
            let parts = entry.path.split(separator: "/").map(String.init)
            var path = ""
            for part in parts {
                path = path.isEmpty ? part : path + "/" + part
                if folders[path] == nil { folders[path] = [:] }
            }
        }

        func assemble(folderPath: String?) -> [ArchiveNode] {
            var result: [ArchiveNode] = []
            let prefix = folderPath.map { $0 + "/" } ?? ""
            let folderPaths = folders.keys.filter { key in
                let parent = key.split(separator: "/").dropLast().joined(separator: "/")
                return parent == (folderPath ?? "") && key != folderPath
            }.sorted()
            for path in folderPaths {
                var children = assemble(folderPath: path)
                let directFiles = files.values.filter { file in
                    file.path.hasPrefix(prefix) && file.path.dropFirst(prefix.count).split(separator: "/").count == 1
                }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                children.append(contentsOf: directFiles)
                let entry = sorted.first { $0.isDirectory && $0.path == path }
                result.append(ArchiveNode(name: path.split(separator: "/").last.map(String.init) ?? path,
                                          path: path, entry: entry, children: children))
            }
            if folderPath == nil {
                result.append(contentsOf: files.values.filter { !$0.path.contains("/") }.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                })
            }
            return result
        }
        return assemble(folderPath: nil)
    }

    var descendantFiles: [ArchiveEntry] {
        if let entry, children == nil { return [entry] }
        return (children ?? []).flatMap(\.descendantFiles)
    }

    var descendantEntries: [ArchiveEntry] {
        let own = entry.map { [$0] } ?? []
        return own + (children ?? []).flatMap(\.descendantEntries)
    }
}

struct ExtractionResult: Equatable {
    let directory: URL
    let workspace: URL
    let fileCount: Int
    let byteCount: Int64
}
