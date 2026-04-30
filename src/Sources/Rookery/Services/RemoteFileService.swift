import Foundation

struct RemoteFileMetadata: Sendable, Hashable {
    let size: UInt64
    let mtime: Date?
}

/// Abstraction over a filesystem the app can browse, read, and write —
/// either remote (SFTP via Citadel) or local (FileManager). Both kinds plug
/// into the same SessionState and the same UI.
protocol RemoteFileService: Sendable {
    func connect(profile: HostProfile) async throws
    func disconnect() async
    func resolveHome() async throws -> String
    func listDirectory(at path: String) async throws -> [RemoteFileEntry]
    func statFile(at path: String) async throws -> RemoteFileMetadata
    func readFile(at path: String, maxBytes: Int) async throws -> Data
    func writeFile(at path: String, contents: Data) async throws
}
