import Foundation

/// Abstraction over a filesystem the app can browse and read — either remote
/// (SFTP via Citadel) or local (FileManager). Both kinds plug into the same
/// SessionState and the same UI.
protocol RemoteFileService: Sendable {
    func connect(profile: HostProfile) async throws
    func disconnect() async
    func resolveHome() async throws -> String
    func listDirectory(at path: String) async throws -> [RemoteFileEntry]
    func readTextFile(at path: String) async throws -> String
}
