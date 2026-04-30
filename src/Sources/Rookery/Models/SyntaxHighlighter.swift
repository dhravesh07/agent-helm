import Foundation
import AppKit

/// Lightweight regex-based syntax highlighter. Pure Swift, no JS runtime.
/// Each language is a list of `Rule`s applied in order — later rules win on
/// overlap (so e.g. comments override "looks like a keyword inside a comment").
struct SyntaxRule {
    let regex: NSRegularExpression
    let token: SyntaxToken
}

enum SyntaxToken {
    case keyword
    case string
    case number
    case comment
    case symbol      // YAML keys, JSON keys, etc.
    case builtin     // null, true, false

    var color: NSColor {
        switch self {
        case .keyword: return NSColor.systemPurple
        case .string:  return NSColor.systemGreen
        case .number:  return NSColor.systemOrange
        case .comment: return NSColor.secondaryLabelColor
        case .symbol:  return NSColor.systemBlue
        case .builtin: return NSColor.systemPink
        }
    }
}

struct LanguageSpec {
    let name: String
    let extensions: Set<String>
    let rules: [SyntaxRule]
}

enum SyntaxLanguages {
    static let all: [LanguageSpec] = [swift, python, javascript, json, yaml, toml, shell, ruby, go, rust]

    static func spec(forExtension ext: String) -> LanguageSpec? {
        let lower = ext.lowercased()
        return all.first { $0.extensions.contains(lower) }
    }

    static func spec(for entry: RemoteFileEntry) -> LanguageSpec? {
        spec(forExtension: (entry.name as NSString).pathExtension)
    }

    // MARK: - Languages

    private static func rule(_ pattern: String, _ token: SyntaxToken, options: NSRegularExpression.Options = []) -> SyntaxRule? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        return SyntaxRule(regex: r, token: token)
    }

    static let swift: LanguageSpec = LanguageSpec(
        name: "swift",
        extensions: ["swift"],
        rules: [
            // Order matters: comments / strings first so keywords inside don't override.
            rule(#"//[^\n]*"#, .comment),
            rule(#"/\*[\s\S]*?\*/"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(let|var|func|class|struct|enum|protocol|extension|import|return|if|else|guard|switch|case|default|for|while|do|try|catch|throws|throw|async|await|public|private|internal|fileprivate|open|static|final|override|init|deinit|self|Self|where|as|is|in|inout|some|any|defer|repeat|break|continue|fallthrough|typealias|associatedtype|operator|prefix|postfix|infix|nonisolated)\b"#, .keyword),
            rule(#"\b(nil|true|false)\b"#, .builtin),
            rule(#"@\w+"#, .keyword),
        ].compactMap { $0 }
    )

    static let python: LanguageSpec = LanguageSpec(
        name: "python",
        extensions: ["py", "pyi", "pyx"],
        rules: [
            rule(#"#[^\n]*"#, .comment),
            rule(#"\"\"\"[\s\S]*?\"\"\""#, .string),
            rule(#"'''[\s\S]*?'''"#, .string),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'(?:\\.|[^'\\])*'"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(def|class|return|if|elif|else|for|while|in|not|and|or|import|from|as|with|try|except|finally|raise|pass|break|continue|lambda|yield|global|nonlocal|async|await|is|del|assert|match|case)\b"#, .keyword),
            rule(#"\b(None|True|False|self|cls)\b"#, .builtin),
            rule(#"@\w+"#, .keyword),
        ].compactMap { $0 }
    )

    static let javascript: LanguageSpec = LanguageSpec(
        name: "javascript",
        extensions: ["js", "jsx", "ts", "tsx", "mjs", "cjs"],
        rules: [
            rule(#"//[^\n]*"#, .comment),
            rule(#"/\*[\s\S]*?\*/"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'(?:\\.|[^'\\])*'"#, .string),
            rule(#"`(?:\\.|[^`\\])*`"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(const|let|var|function|class|return|if|else|for|while|do|switch|case|default|break|continue|new|this|typeof|instanceof|in|of|import|export|from|async|await|try|catch|finally|throw|delete|void|yield|interface|type|enum|extends|implements|public|private|protected|static|readonly|abstract|as|namespace|declare|keyof|infer|satisfies)\b"#, .keyword),
            rule(#"\b(null|undefined|true|false|NaN|Infinity)\b"#, .builtin),
        ].compactMap { $0 }
    )

    static let json: LanguageSpec = LanguageSpec(
        name: "json",
        extensions: ["json", "jsonl", "geojson"],
        rules: [
            rule(#""(?:\\.|[^"\\])*"(?=\s*:)"#, .symbol),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number),
            rule(#"\b(true|false|null)\b"#, .builtin),
        ].compactMap { $0 }
    )

    static let yaml: LanguageSpec = LanguageSpec(
        name: "yaml",
        extensions: ["yaml", "yml"],
        rules: [
            rule(#"#[^\n]*"#, .comment),
            rule(#"^[\s-]*([a-zA-Z_][\w.-]*)\s*:"#, .symbol, options: .anchorsMatchLines),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'[^']*'"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(true|false|null|yes|no|~)\b"#, .builtin),
        ].compactMap { $0 }
    )

    static let toml: LanguageSpec = LanguageSpec(
        name: "toml",
        extensions: ["toml"],
        rules: [
            rule(#"#[^\n]*"#, .comment),
            rule(#"^\s*\[[\w.\-]+\]"#, .keyword, options: .anchorsMatchLines),
            rule(#"^\s*([\w.\-]+)\s*="#, .symbol, options: .anchorsMatchLines),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'[^']*'"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(true|false)\b"#, .builtin),
        ].compactMap { $0 }
    )

    static let shell: LanguageSpec = LanguageSpec(
        name: "shell",
        extensions: ["sh", "bash", "zsh", "fish", "ksh"],
        rules: [
            rule(#"#[^\n]*"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'[^']*'"#, .string),
            rule(#"\$\{?[A-Za-z_]\w*\}?"#, .symbol),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(if|then|else|elif|fi|for|in|do|done|while|until|case|esac|function|return|local|export|set|unset|echo|printf|cd|pwd|test|true|false|source|alias|exit|trap)\b"#, .keyword),
        ].compactMap { $0 }
    )

    static let ruby: LanguageSpec = LanguageSpec(
        name: "ruby",
        extensions: ["rb", "ru", "rake", "gemspec"],
        rules: [
            rule(#"#[^\n]*"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"'[^']*'"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(def|end|class|module|return|if|elsif|else|unless|while|until|do|begin|rescue|ensure|raise|require|require_relative|include|extend|attr_accessor|attr_reader|attr_writer|private|protected|public|self|new|then|case|when|in|yield|lambda|proc|loop|break|next|redo|retry)\b"#, .keyword),
            rule(#"\b(nil|true|false)\b"#, .builtin),
            rule(#":[a-zA-Z_]\w*"#, .symbol),
        ].compactMap { $0 }
    )

    static let go: LanguageSpec = LanguageSpec(
        name: "go",
        extensions: ["go"],
        rules: [
            rule(#"//[^\n]*"#, .comment),
            rule(#"/\*[\s\S]*?\*/"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"`[^`]*`"#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(package|import|func|var|const|type|struct|interface|return|if|else|for|range|switch|case|default|break|continue|fallthrough|go|defer|chan|select|map|make|new|nil|true|false|iota)\b"#, .keyword),
        ].compactMap { $0 }
    )

    static let rust: LanguageSpec = LanguageSpec(
        name: "rust",
        extensions: ["rs"],
        rules: [
            rule(#"//[^\n]*"#, .comment),
            rule(#"/\*[\s\S]*?\*/"#, .comment),
            rule(#""(?:\\.|[^"\\])*""#, .string),
            rule(#"\b\d+(?:\.\d+)?\b"#, .number),
            rule(#"\b(fn|let|mut|const|static|struct|enum|trait|impl|pub|use|mod|crate|extern|return|if|else|for|while|loop|match|break|continue|in|as|ref|move|where|dyn|async|await|unsafe|self|Self|true|false)\b"#, .keyword),
            rule(#"\b(None|Some|Ok|Err)\b"#, .builtin),
        ].compactMap { $0 }
    )
}

/// Applies a `LanguageSpec`'s rules to text and returns ranges to color.
struct SyntaxHighlighter {
    static func highlight(_ text: String, with spec: LanguageSpec) -> [(range: NSRange, color: NSColor)] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var attributes: [(range: NSRange, color: NSColor)] = []
        for rule in spec.rules {
            rule.regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match else { return }
                attributes.append((match.range, rule.token.color))
            }
        }
        return attributes
    }
}
