import Foundation

struct SafeArchivePath: Hashable {
    let components: [String]

    init(_ rawValue: String) throws {
        guard !rawValue.isEmpty, !rawValue.contains("\0") else {
            throw ArchiveError.unsafePath(rawValue)
        }
        let value = rawValue.replacingOccurrences(of: "\\", with: "/")
        guard !value.hasPrefix("/") else { throw ArchiveError.unsafePath(rawValue) }
        let withoutTrailingSlash = value.hasSuffix("/") ? String(value.dropLast()) : value
        let parts = withoutTrailingSlash.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else { throw ArchiveError.unsafePath(rawValue) }
        for (index, part) in parts.enumerated() {
            let hasControlCharacter = part.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
            if part.isEmpty || part == "." || part == ".." || hasControlCharacter || (index == 0 && part.contains(":")) {
                throw ArchiveError.unsafePath(rawValue)
            }
        }
        components = parts
    }

    var relativePath: String { components.joined(separator: "/") }
    var lastComponent: String { components[components.count - 1] }

    func url(under root: URL) throws -> URL {
        var candidate = root.standardizedFileURL
        for component in components {
            candidate.appendPathComponent(component, isDirectory: false)
        }
        candidate = candidate.standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidate.path.hasPrefix(prefix), candidate.path != rootPath else {
            throw ArchiveError.unsafePath(relativePath)
        }
        return candidate
    }
}
