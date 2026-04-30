import Foundation

enum LocalFileServiceError: LocalizedError {
    case rootNotFound(path: String)
    case rootNotDirectory(path: String)
    case readFailed(path: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound(let p):
            return "Path does not exist: \(p)"
        case .rootNotDirectory(let p):
            return "Path is not a directory: \(p)"
        case .readFailed(let p, let m):
            return "Could not read file at \(p): \(m)"
        }
    }
}

actor LocalFileService: RemoteFileService {
    private var connectedRoot: String?

    func connect(profile: HostProfile) async throws {
        let resolved = Self.expand(profile.rootPath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else {
            throw LocalFileServiceError.rootNotFound(path: resolved)
        }
        guard isDir.boolValue else {
            throw LocalFileServiceError.rootNotDirectory(path: resolved)
        }
        self.connectedRoot = resolved
    }

    func disconnect() async {
        self.connectedRoot = nil
    }

    func resolveHome() async throws -> String {
        Self.expand("~")
    }

    func listDirectory(at path: String) async throws -> [RemoteFileEntry] {
        let resolved = Self.expand(path)
        let url = URL(fileURLWithPath: resolved, isDirectory: true)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        let entries: [RemoteFileEntry] = contents.compactMap { fileURL in
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDir = values?.isDirectory ?? false
            let size = values?.fileSize.map { UInt64($0) }
            return RemoteFileEntry(
                id: fileURL.path,
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDir,
                size: isDir ? nil : size
            )
        }
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func readTextFile(at path: String) async throws -> String {
        let resolved = Self.expand(path)
        do {
            return try String(contentsOfFile: resolved, encoding: .utf8)
        } catch {
            throw LocalFileServiceError.readFailed(path: resolved, underlying: error.localizedDescription)
        }
    }

    private static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
