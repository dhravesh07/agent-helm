import Foundation

struct RemoteFileEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64?

    var isMarkdown: Bool {
        name.lowercased().hasSuffix(".md") || name.lowercased().hasSuffix(".markdown")
    }
}
