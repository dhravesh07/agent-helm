import Foundation

struct HostProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var privateKeyPath: String
    var rootPath: String

    init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String,
        rootPath: String = "~"
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
        self.rootPath = rootPath
    }
}
