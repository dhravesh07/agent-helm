import Foundation

enum FileBufferState: Equatable {
    case empty
    case loading
    case text(original: String)
    case image(data: Data)
    case pdf(data: Data)
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
    case preview      // markdown render, XML pretty
    case graph        // JSON node-graph
    case formatted    // JSON pretty-print (text)
    case source       // raw text editor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview:   return "Preview"
        case .graph:     return "Graph"
        case .formatted: return "Pretty"
        case .source:    return "Source"
        }
    }

    var systemImage: String {
        switch self {
        case .preview:   return "doc.richtext"
        case .graph:     return "point.3.connected.trianglepath.dotted"
        case .formatted: return "text.alignleft"
        case .source:    return "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved(at: Date)
    case failed(message: String)
}
