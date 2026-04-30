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
    var workspaces: [Workspace]

    init(
        id: UUID = UUID(),
        kind: HostKind = .remote,
        name: String,
        hostname: String = "",
        port: Int = 22,
        username: String = "",
        privateKeyPath: String = "",
        workspaces: [Workspace] = [Workspace(name: "Root", path: "~")]
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
        self.workspaces = workspaces.isEmpty ? [Workspace(name: "Root", path: "~")] : workspaces
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, hostname, port, username, privateKeyPath
        case workspaces
        case rootPath  // legacy v0.0.3–v0.0.8 single-path field
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.kind = try c.decodeIfPresent(HostKind.self, forKey: .kind) ?? .remote
        self.name = try c.decode(String.self, forKey: .name)
        self.hostname = try c.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        self.port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 22
        self.username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.privateKeyPath = try c.decodeIfPresent(String.self, forKey: .privateKeyPath) ?? ""

        if let ws = try c.decodeIfPresent([Workspace].self, forKey: .workspaces), !ws.isEmpty {
            self.workspaces = ws
        } else {
            // Migrate from legacy single rootPath. v0.0.9 onwards.
            let legacy = try c.decodeIfPresent(String.self, forKey: .rootPath)
            let path = (legacy?.isEmpty == false ? legacy! : "~")
            self.workspaces = [Workspace(name: "Root", path: path)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(name, forKey: .name)
        try c.encode(hostname, forKey: .hostname)
        try c.encode(port, forKey: .port)
        try c.encode(username, forKey: .username)
        try c.encode(privateKeyPath, forKey: .privateKeyPath)
        try c.encode(workspaces, forKey: .workspaces)
        // rootPath intentionally not written; field is legacy-decode-only.
    }
}
