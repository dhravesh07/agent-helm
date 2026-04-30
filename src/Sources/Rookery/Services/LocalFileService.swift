import Foundation

enum LocalFileServiceError: LocalizedError {
    case rootNotFound(path: String)
    case rootNotDirectory(path: String)
    case readFailed(path: String, underlying: String)
    case writeFailed(path: String, underlying: String)
    case statFailed(path: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound(let p):
            return "Path does not exist: \(p)"
        case .rootNotDirectory(let p):
            return "Path is not a directory: \(p)"
        case .readFailed(let p, let m):
            return "Could not read file at \(p): \(m)"
        case .writeFailed(let p, let m):
            return "Could not write file at \(p): \(m)"
        case .statFailed(let p, let m):
            return "Could not stat file at \(p): \(m)"
        }
    }
}

actor LocalFileService: RemoteFileService {
    private var isOpen = false

    func connect(profile: HostProfile) async throws {
        // No real connection to make for local. Each workspace's path is
        // validated on first listDirectory call so a missing path on one
        // workspace doesn't block the others.
        isOpen = true
    }

    func disconnect() async {
        isOpen = false
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

    func statFile(at path: String) async throws -> RemoteFileMetadata {
        let resolved = Self.expand(path)
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: resolved)
            let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
            let mtime = attrs[.modificationDate] as? Date
            return RemoteFileMetadata(size: size, mtime: mtime)
        } catch {
            throw LocalFileServiceError.statFailed(path: resolved, underlying: error.localizedDescription)
        }
    }

    func readFile(at path: String, maxBytes: Int) async throws -> Data {
        let resolved = Self.expand(path)
        do {
            let url = URL(fileURLWithPath: resolved)
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return try handle.read(upToCount: maxBytes) ?? Data()
        } catch {
            throw LocalFileServiceError.readFailed(path: resolved, underlying: error.localizedDescription)
        }
    }

    func writeFile(at path: String, contents: Data) async throws {
        let resolved = Self.expand(path)
        let url = URL(fileURLWithPath: resolved)
        do {
            try contents.write(to: url, options: .atomic)
        } catch {
            throw LocalFileServiceError.writeFailed(path: resolved, underlying: error.localizedDescription)
        }
    }

    func runShellCommand(_ command: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            do {
                try process.run()
            } catch {
                throw LocalFileServiceError.readFailed(
                    path: command,
                    underlying: "Could not launch /bin/sh: \(error.localizedDescription)"
                )
            }
            process.waitUntilExit()
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                let combined = errStr.isEmpty ? outStr : errStr
                throw LocalFileServiceError.readFailed(
                    path: command,
                    underlying: "Exit \(process.terminationStatus): \(combined)"
                )
            }
            return outStr
        }.value
    }

    private static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
