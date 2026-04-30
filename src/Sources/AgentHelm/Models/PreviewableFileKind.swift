import Foundation

enum PreviewableFileKind: Equatable {
    case markdown
    case json
    case xml
    case image
    case pdf
    case sourceText

    /// View modes available for this kind, in display order. Empty means no
    /// toggle — render the single appropriate view (image, pdf, plain source).
    var availableViewModes: [FileViewMode] {
        switch self {
        case .markdown:   return [.preview, .source]
        case .json:       return [.graph, .formatted, .source]
        case .xml:        return [.preview, .source]
        case .image, .pdf, .sourceText: return []
        }
    }

    var defaultViewMode: FileViewMode {
        availableViewModes.first ?? .source
    }

    var isEditableText: Bool {
        switch self {
        case .markdown, .json, .xml, .sourceText: return true
        case .image, .pdf: return false
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
        case "xml", "plist", "xib", "storyboard", "rss", "atom", "svg":
            return .xml
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
