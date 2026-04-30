import Foundation

enum FileBufferState: Equatable {
    case empty
    case loading
    case text(original: String)
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
    case preview
    case source

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return "Preview"
        case .source:  return "Source"
        }
    }

    var systemImage: String {
        switch self {
        case .preview: return "doc.richtext"
        case .source:  return "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved(at: Date)
    case failed(message: String)
}
