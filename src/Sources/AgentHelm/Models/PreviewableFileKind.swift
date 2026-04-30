import Foundation

enum PreviewableFileKind: Equatable {
    case markdown
    case json
    case image
    case pdf
    case sourceText

    /// Whether this kind has a non-source preview that's worth toggling to.
    /// Markdown and JSON have a Preview/Source toggle; image/pdf are
    /// preview-only; sourceText only has a source view.
    var supportsPreviewToggle: Bool {
        switch self {
        case .markdown, .json: return true
        case .image, .pdf, .sourceText: return false
        }
    }

    /// Whether this kind is editable as text. Images and PDFs are not.
    var isEditableText: Bool {
        switch self {
        case .markdown, .json, .sourceText: return true
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
