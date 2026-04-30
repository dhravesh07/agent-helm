import Foundation

enum PreviewableFileKind: Equatable {
    case markdown
    case json
    case jsonl
    case xml
    case sqlite
    case image
    case pdf
    case sourceText

    /// View modes available for this kind, in display order. Empty means no
    /// toggle — render the single appropriate view (image, pdf, plain source).
    var availableViewModes: [FileViewMode] {
        switch self {
        case .markdown:   return [.preview, .source]
        case .json:       return [.graph, .formatted, .source]
        case .jsonl:      return [.transcript, .source]
        case .xml:        return [.preview, .source]
        case .sqlite:     return [.tables, .schema, .query]
        case .image, .pdf, .sourceText: return []
        }
    }

    var defaultViewMode: FileViewMode {
        availableViewModes.first ?? .source
    }

    var isEditableText: Bool {
        switch self {
        case .markdown, .json, .jsonl, .xml, .sourceText: return true
        case .image, .pdf, .sqlite: return false
        }
    }
}

extension RemoteFileEntry {
    var previewableKind: PreviewableFileKind {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdown", "mkd":
            return .markdown
        case "json":
            return .json
        case "jsonl", "ndjson":
            return .jsonl
        case "xml", "plist", "xib", "storyboard", "rss", "atom", "svg":
            return .xml
        case "db", "sqlite", "sqlite3", "db3":
            return .sqlite
        case "png", "jpg", "jpeg", "gif", "heic", "heif",
             "tiff", "tif", "bmp", "webp", "ico", "icns":
            return .image
        case "pdf":
            return .pdf
        default:
            return .sourceText
        }
    }
}
