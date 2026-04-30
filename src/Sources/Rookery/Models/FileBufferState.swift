import Foundation

enum FileBufferState: Equatable {
    case empty
    case loading
    case text(original: String)
    case image(data: Data)
    case pdf(data: Data)
    case sqlite(localPath: URL, size: UInt64)
    case binary(size: UInt64)
    case tooLarge(size: UInt64)
    case error(message: String)

    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    var originalText: String? {
        if case .text(let s) = self { return s }
        return nil
    }
}

enum FileViewMode: String, CaseIterable, Identifiable {
    // Generic / shared
    case preview        // markdown render, XML pretty
    case graph          // JSON node-graph
    case formatted      // JSON pretty-print (text)
    case source         // raw text editor

    // JSONL transcripts
    case transcript     // one message per row, expandable

    // SQLite
    case tables         // sidebar of tables + paginated row view
    case schema         // CREATE TABLE + column info
    case query          // read-only SQL editor + results

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview:    return "Preview"
        case .graph:      return "Graph"
        case .formatted:  return "Pretty"
        case .source:     return "Source"
        case .transcript: return "Transcript"
        case .tables:     return "Tables"
        case .schema:     return "Schema"
        case .query:      return "Query"
        }
    }

    var systemImage: String {
        switch self {
        case .preview:    return "doc.richtext"
        case .graph:      return "point.3.connected.trianglepath.dotted"
        case .formatted:  return "text.alignleft"
        case .source:     return "chevron.left.forwardslash.chevron.right"
        case .transcript: return "bubble.left.and.bubble.right"
        case .tables:     return "tablecells"
        case .schema:     return "list.bullet.rectangle"
        case .query:      return "terminal"
        }
    }
}

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved(at: Date)
    case failed(message: String)
}
