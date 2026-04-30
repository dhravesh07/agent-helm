import Foundation

enum HostKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case local
    case remote

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: return "Local (this Mac)"
        case .remote: return "Remote (SSH)"
        }
    }

    var systemImage: String {
        switch self {
        case .local: return "macbook"
        case .remote: return "server.rack"
        }
    }
}

struct HostProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: HostKind
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var privateKeyPath: String
    var rootPath: String

    init(
        id: UUID = UUID(),
        kind: HostKind = .remote,
        name: String,
        hostname: String = "",
        port: Int = 22,
        username: String = "",
        privateKeyPath: String = "",
        rootPath: String = "~"
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
        self.rootPath = rootPath
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, hostname, port, username, privateKeyPath, rootPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        // Default to .remote so existing v0.0.3 stored profiles decode cleanly.
        self.kind = try c.decodeIfPresent(HostKind.self, forKey: .kind) ?? .remote
        self.name = try c.decode(String.self, forKey: .name)
        self.hostname = try c.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        self.port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 22
        self.username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.privateKeyPath = try c.decodeIfPresent(String.self, forKey: .privateKeyPath) ?? ""
        self.rootPath = try c.decodeIfPresent(String.self, forKey: .rootPath) ?? "~"
    }
}
