import Foundation

/// A named path within a host. Hosts can have many — Skills, Project, Notes,
/// etc. — and the user switches between them via the file-browser header.
struct Workspace: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
