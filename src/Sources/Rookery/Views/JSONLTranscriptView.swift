import SwiftUI

/// JSONL transcript viewer. Each line is parsed as a JSON object; rows render
/// one message per line with role-based coloring and inline expansion. Common
/// agent-transcript shapes are recognized: `role` + `content`, `type` +
/// `message`, plus a passthrough for arbitrary objects.
struct JSONLTranscriptView: View {
    let raw: String

    @State private var search: String = ""
    @State private var expandedIds: Set<Int> = []

    private var entries: [TranscriptEntry] {
        TranscriptParser.parse(raw)
    }

    private var filtered: [TranscriptEntry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { entry in
            entry.preview.lowercased().contains(q)
                || entry.role.lowercased().contains(q)
                || entry.raw.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search messages, roles, raw JSON…", text: $search)
                .textFieldStyle(.plain)
            Spacer()
            Text("\(filtered.count) of \(entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No JSONL messages found")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { entry in
                        TranscriptRow(
                            entry: entry,
                            isExpanded: expandedIds.contains(entry.id),
                            toggle: {
                                if expandedIds.contains(entry.id) {
                                    expandedIds.remove(entry.id)
                                } else {
                                    expandedIds.insert(entry.id)
                                }
                            }
                        )
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct TranscriptRow: View {
    let entry: TranscriptEntry
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button(action: toggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)

                Text("#\(entry.lineNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)

                roleBadge
                    .frame(width: 90, alignment: .leading)

                Text(entry.preview)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { toggle() }

            if isExpanded {
                expandedDetail
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(roleTint)
    }

    private var roleBadge: some View {
        Text(entry.role)
            .font(.caption.monospaced())
            .foregroundStyle(roleColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }

    private var roleColor: Color {
        switch entry.role.lowercased() {
        case "user", "human": return .blue
        case "assistant", "claude", "ai": return .purple
        case "system": return .gray
        case "tool", "tool_result", "function": return .orange
        case "error": return .red
        default: return .secondary
        }
    }

    private var roleTint: Color {
        if isExpanded {
            return roleColor.opacity(0.04)
        }
        return entry.lineNumber.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.04)
    }

    @ViewBuilder
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !entry.body.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(entry.body)
                        .font(.system(.body))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !entry.toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tool calls")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(Array(entry.toolCalls.enumerated()), id: \.offset) { _, call in
                        Text(call)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            DisclosureGroup("Raw JSON") {
                Text(entry.pretty)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .font(.caption.bold())
            .tint(.secondary)
        }
        .padding(.leading, 130)  // align with the "preview" column
    }
}

// MARK: - Parser

private struct TranscriptEntry: Identifiable {
    let id: Int
    let lineNumber: Int
    let role: String
    let preview: String
    let body: String
    let toolCalls: [String]
    let raw: String
    let pretty: String
}

private enum TranscriptParser {
    static func parse(_ raw: String) -> [TranscriptEntry] {
        var entries: [TranscriptEntry] = []
        var lineNumber = 0
        raw.enumerateLines { line, _ in
            lineNumber += 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard let data = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            else {
                entries.append(TranscriptEntry(
                    id: entries.count,
                    lineNumber: lineNumber,
                    role: "raw",
                    preview: trimmed,
                    body: trimmed,
                    toolCalls: [],
                    raw: trimmed,
                    pretty: trimmed
                ))
                return
            }

            let dict = object as? [String: Any] ?? [:]
            let role = roleString(from: dict)
            let body = bodyString(from: dict)
            let toolCalls = toolCallsArray(from: dict)
            let preview = body.isEmpty ? Self.summarize(dict) : Self.firstLine(body)
            let pretty: String = {
                if let data = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                ), let s = String(data: data, encoding: .utf8) {
                    return s
                }
                return trimmed
            }()

            entries.append(TranscriptEntry(
                id: entries.count,
                lineNumber: lineNumber,
                role: role,
                preview: preview,
                body: body,
                toolCalls: toolCalls,
                raw: trimmed,
                pretty: pretty
            ))
        }
        return entries
    }

    private static func roleString(from dict: [String: Any]) -> String {
        if let r = dict["role"] as? String { return r }
        if let t = dict["type"] as? String { return t }
        if let s = dict["sender"] as? String { return s }
        return "—"
    }

    private static func bodyString(from dict: [String: Any]) -> String {
        // Common shapes: content as string, content as array of {type,text}.
        if let content = dict["content"] as? String { return content }
        if let content = dict["content"] as? [[String: Any]] {
            let parts: [String] = content.compactMap { item in
                if let text = item["text"] as? String { return text }
                if let type = item["type"] as? String { return "[\(type)]" }
                return nil
            }
            return parts.joined(separator: "\n")
        }
        if let message = dict["message"] as? String { return message }
        if let text = dict["text"] as? String { return text }
        return ""
    }

    private static func toolCallsArray(from dict: [String: Any]) -> [String] {
        guard let calls = dict["tool_calls"] as? [[String: Any]] else { return [] }
        return calls.compactMap { call in
            if let data = try? JSONSerialization.data(
                withJSONObject: call,
                options: [.prettyPrinted, .sortedKeys]
            ), let s = String(data: data, encoding: .utf8) {
                return s
            }
            return nil
        }
    }

    private static func firstLine(_ s: String) -> String {
        s.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? s
    }

    private static func summarize(_ dict: [String: Any]) -> String {
        let keys = dict.keys.sorted().prefix(5).joined(separator: ", ")
        return "{\(keys)\(dict.count > 5 ? ", …" : "")}"
    }
}
