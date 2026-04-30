import Foundation
import Citadel
import Crypto
import NIOCore
import NIOSSH

enum SSHServiceError: LocalizedError {
    case keyFileNotReadable(path: String)
    case unsupportedKeyFormat
    case notConnected
    case remoteRead(String)
    case remoteWrite(String)

    var errorDescription: String? {
        switch self {
        case .keyFileNotReadable(let p):
            return "Private key file is not readable: \(p)"
        case .unsupportedKeyFormat:
            return "Only OpenSSH ed25519 and RSA keys are supported in v0.0.6."
        case .notConnected:
            return "Not connected to a host."
        case .remoteRead(let m):
            return "Remote read failed: \(m)"
        case .remoteWrite(let m):
            return "Remote write failed: \(m)"
        }
    }
}

actor SSHService: RemoteFileService {
    private var client: SSHClient?
    private var sftp: SFTPClient?

    func connect(profile: HostProfile) async throws {
        await disconnectInternal()

        let auth = try Self.makeAuthMethod(profile: profile)
        let validator: SSHHostKeyValidator = .acceptAnything()

        let connected = try await SSHClient.connect(
            host: profile.hostname,
            port: profile.port,
            authenticationMethod: auth,
            hostKeyValidator: validator,
            reconnect: .never
        )

        let sftpClient = try await connected.openSFTP()
        self.client = connected
        self.sftp = sftpClient
    }

    func disconnect() async {
        await disconnectInternal()
    }

    private func disconnectInternal() async {
        if let sftp { try? await sftp.close() }
        if let client { try? await client.close() }
        self.sftp = nil
        self.client = nil
    }

    func resolveHome() async throws -> String {
        guard let client else { throw SSHServiceError.notConnected }
        let buffer = try await client.executeCommand("printf %s \"$HOME\"")
        let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) ?? []
        let raw = String(bytes: bytes, encoding: .utf8) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "/" : trimmed
    }

    func listDirectory(at path: String) async throws -> [RemoteFileEntry] {
        guard let sftp else { throw SSHServiceError.notConnected }
        let names = try await sftp.listDirectory(atPath: path)
        var entries: [RemoteFileEntry] = []
        for name in names {
            for component in name.components {
                let filename = component.filename
                if filename == "." || filename == ".." { continue }
                let fullPath = path.hasSuffix("/") ? path + filename : path + "/" + filename
                let isDir = component.attributes.permissions.map { $0 & 0o040000 != 0 } ?? false
                entries.append(
                    RemoteFileEntry(
                        id: fullPath,
                        name: filename,
                        path: fullPath,
                        isDirectory: isDir,
                        size: component.attributes.size
                    )
                )
            }
        }
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func statFile(at path: String) async throws -> RemoteFileMetadata {
        guard let sftp else { throw SSHServiceError.notConnected }
        let attrs = try await sftp.withFile(filePath: path, flags: .read) { file in
            try await file.readAttributes()
        }
        return RemoteFileMetadata(
            size: attrs.size ?? 0,
            mtime: attrs.accessModificationTime?.modificationTime
        )
    }

    func readFile(at path: String, maxBytes: Int) async throws -> Data {
        guard let sftp else { throw SSHServiceError.notConnected }
        let length = UInt32(min(maxBytes, Int(UInt32.max)))
        let buffer = try await sftp.withFile(filePath: path, flags: .read) { file in
            try await file.read(from: 0, length: length)
        }
        let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) ?? []
        return Data(bytes)
    }

    func writeFile(at path: String, contents: Data) async throws {
        guard let sftp else { throw SSHServiceError.notConnected }
        do {
            try await sftp.withFile(
                filePath: path,
                flags: [.write, .create, .truncate]
            ) { file in
                var buffer = ByteBuffer()
                buffer.writeBytes(contents)
                try await file.write(buffer, at: 0)
            }
        } catch {
            throw SSHServiceError.remoteWrite(error.localizedDescription)
        }
    }

    private static func makeAuthMethod(profile: HostProfile) throws -> SSHAuthenticationMethod {
        let expandedPath = (profile.privateKeyPath as NSString).expandingTildeInPath
        guard FileManager.default.isReadableFile(atPath: expandedPath),
              let keyContents = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            throw SSHServiceError.keyFileNotReadable(path: expandedPath)
        }

        if let ed25519 = try? Curve25519.Signing.PrivateKey(sshEd25519: keyContents) {
            return .ed25519(username: profile.username, privateKey: ed25519)
        }
        if let rsa = try? Insecure.RSA.PrivateKey(sshRsa: keyContents) {
            return .rsa(username: profile.username, privateKey: rsa)
        }
        throw SSHServiceError.unsupportedKeyFormat
    }
}
