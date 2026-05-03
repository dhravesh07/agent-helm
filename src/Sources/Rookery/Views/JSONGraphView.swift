import SwiftUI
import AppKit

// MARK: - JSON value type

/// In-memory mutable JSON tree. Easier to mutate than `JSONSerialization`'s
/// NSDictionary/NSArray output. Round-trips through Codable for serialization.
indirect enum JSONValue: Equatable {
    case object([(String, JSONValue)])  // ordered
    case array([JSONValue])
    case string(String)
    case number(Double)
    case integer(Int64)
    case bool(Bool)
    case null

    static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.integer(let a), .integer(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: return false
        }
    }

    var displayString: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .integer(let i): return "\(i)"
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0 && abs(n) < 1e15 {
                return "\(Int64(n))"
            }
            return "\(n)"
        case .string(let s): return "\"\(s)\""
        case .array(let arr): return "[\(arr.count) item\(arr.count == 1 ? "" : "s")]"
        case .object(let obj): return "{\(obj.count) key\(obj.count == 1 ? "" : "s")}"
        }
    }

    var isContainer: Bool {
        if case .array = self { return true }
        if case .object = self { return true }
        return false
    }
}

// MARK: - Parsing

private enum JSONValueParser {
    static func parse(_ raw: String) -> JSONValue? {
        guard let data = raw.data(using: .utf8) else { return nil }
        do {
            // We need ordered keys, so parse JSON ourselves with JSONDecoder
            // semantics — but JSONSerialization produces a dictionary that
            // loses order. Use raw bytes via JSONDecoder on a wrapper… or
            // walk the structure preserving original key order via JSONLexer.
            // For v0.0.9 we use JSONSerialization and tolerate alphabetical
            // key order on round-trip. JSONSerialization.WritingOptions
            // .sortedKeys gives us a stable round-trip.
            let object = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
            return convert(object)
        } catch {
            return nil
        }
    }

    private static func convert(_ value: Any) -> JSONValue {
        if value is NSNull { return .null }
        if let b = value as? Bool { return .bool(b) }
        if let n = value as? NSNumber {
            // NSNumber covers both Bool and numeric; the Bool case is caught
            // above by `as? Bool` because NSNumber wraps booleans.
            if CFNumberIsFloatType(n) {
                return .number(n.doubleValue)
            }
            return .integer(n.int64Value)
        }
        if let s = value as? String { return .string(s) }
        if let arr = value as? [Any] {
            return .array(arr.map { convert($0) })
        }
        if let dict = value as? [String: Any] {
            // Sort keys for stability since JSONSerialization doesn't preserve order.
            let pairs = dict.keys.sorted().map { ($0, convert(dict[$0]!)) }
            return .object(pairs)
        }
        return .null
    }
}

// MARK: - Serialization

private enum JSONValueSerializer {
    static func serialize(_ value: JSONValue, pretty: Bool = true) -> String {
        var out = ""
        write(value, into: &out, indent: 0, pretty: pretty)
        return out
    }

    private static func write(_ v: JSONValue, into out: inout String, indent: Int, pretty: Bool) {
        let pad = pretty ? String(repeating: "  ", count: indent) : ""
        let inner = pretty ? String(repeating: "  ", count: indent + 1) : ""
        let nl = pretty ? "\n" : ""

        switch v {
        case .null: out += "null"
        case .bool(let b): out += b ? "true" : "false"
        case .integer(let i): out += "\(i)"
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0 && abs(n) < 1e15 {
                out += "\(Int64(n))"
            } else {
                out += "\(n)"
            }
        case .string(let s):
            out += "\"\(escape(s))\""
        case .array(let items):
            if items.isEmpty { out += "[]"; return }
            out += "[" + nl
            for (idx, item) in items.enumerated() {
                out += inner
                write(item, into: &out, indent: indent + 1, pretty: pretty)
                if idx < items.count - 1 { out += "," }
                out += nl
            }
            out += pad + "]"
        case .object(let pairs):
            if pairs.isEmpty { out += "{}"; return }
            out += "{" + nl
            for (idx, pair) in pairs.enumerated() {
                out += inner + "\"\(escape(pair.0))\": "
                write(pair.1, into: &out, indent: indent + 1, pretty: pretty)
                if idx < pairs.count - 1 { out += "," }
                out += nl
            }
            out += pad + "}"
        }
    }

    private static func escape(_ s: String) -> String {
        var result = ""
        for ch in s {
            switch ch {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if ch.asciiValue.map({ $0 < 0x20 }) ?? false {
                    result += String(format: "\\u%04x", ch.asciiValue!)
                } else {
                    result.append(ch)
                }
            }
        }
        return result
    }
}

// MARK: - Path-based mutation

/// A pointer into a `JSONValue` tree for in-place edits.
enum JSONPathSegment: Equatable {
    case key(String)
    case index(Int)
}

private extension JSONValue {
    /// Returns a copy with the value at `path` replaced. No-op if the path
    /// doesn't resolve.
    func setting(_ newValue: JSONValue, at path: [JSONPathSegment]) -> JSONValue {
        guard !path.isEmpty else { return newValue }
        let head = path[0]
        let tail = Array(path.dropFirst())
        switch (self, head) {
        case (.object(var pairs), .key(let k)):
            if let idx = pairs.firstIndex(where: { $0.0 == k }) {
                pairs[idx] = (k, pairs[idx].1.setting(newValue, at: tail))
            }
            return .object(pairs)
        case (.array(var items), .index(let i)) where (0..<items.count).contains(i):
            items[i] = items[i].setting(newValue, at: tail)
            return .array(items)
        default:
            return self
        }
    }
}

// MARK: - Graph node + layout

private struct JSONGraphNode: Identifiable {
    let id = UUID()
    let title: String
    let path: [JSONPathSegment]
    var rows: [Row]

    enum Row: Identifiable {
        case scalar(id: UUID = UUID(), label: String, value: JSONValue, path: [JSONPathSegment])
        case container(id: UUID = UUID(), label: String, summary: String, child: JSONGraphNode)

        var id: UUID {
            switch self {
            case .scalar(let id, _, _, _): return id
            case .container(let id, _, _, _): return id
            }
        }
    }
}

private struct LaidOutNode: Identifiable {
    let id: UUID
    let model: JSONGraphNode
    var origin: CGPoint
    let size: CGSize
    let rowYs: [UUID: CGFloat]   // row id → absolute y (center)
}

private struct LaidOutEdge {
    let from: CGPoint
    let to: CGPoint
}

private struct GraphLayoutResult {
    let nodes: [LaidOutNode]
    let edges: [LaidOutEdge]
    let canvas: CGSize
}

private enum JSONGraphLayout {
    static let nodeWidth: CGFloat = 280
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 32
    static let collapsedHeight: CGFloat = 32
    static let horizontalGap: CGFloat = 80
    static let verticalGap: CGFloat = 16

    static func compute(
        root: JSONGraphNode,
        collapsedIds: Set<UUID>
    ) -> GraphLayoutResult {
        var laidOut: [LaidOutNode] = []
        var edges: [LaidOutEdge] = []
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        @discardableResult
        func layout(_ node: JSONGraphNode, originX: CGFloat, top: CGFloat) -> (origin: CGPoint, size: CGSize) {
            let collapsed = collapsedIds.contains(node.id)
            let height: CGFloat = collapsed
                ? collapsedHeight
                : headerHeight + CGFloat(node.rows.count) * rowHeight
            let size = CGSize(width: nodeWidth, height: height)

            let childOriginX = originX + nodeWidth + horizontalGap
            var childTop = top
            var childResults: [(rowId: UUID, origin: CGPoint, size: CGSize)] = []

            if !collapsed {
                for row in node.rows {
                    if case .container(let id, _, _, let child) = row {
                        let result = layout(child, originX: childOriginX, top: childTop)
                        childResults.append((rowId: id, origin: result.origin, size: result.size))
                        let consumed = max(result.size.height, height)
                        childTop += consumed + verticalGap
                    }
                }
            }

            let nodeY: CGFloat
            if let first = childResults.first, let last = childResults.last {
                let mid = (first.origin.y + last.origin.y + last.size.height) / 2
                nodeY = mid - height / 2
            } else {
                nodeY = top
            }

            let origin = CGPoint(x: originX, y: nodeY)

            // Per-row Y center (only meaningful when expanded)
            var rowYs: [UUID: CGFloat] = [:]
            if !collapsed {
                for (idx, row) in node.rows.enumerated() {
                    let center = origin.y + headerHeight + CGFloat(idx) * rowHeight + rowHeight / 2
                    rowYs[row.id] = center
                }
            }

            laidOut.append(LaidOutNode(id: node.id, model: node, origin: origin, size: size, rowYs: rowYs))

            // Edges from each container row to its child node's left-center.
            for child in childResults {
                let parentRowY = rowYs[child.rowId] ?? (origin.y + height / 2)
                let from = CGPoint(x: origin.x + nodeWidth, y: parentRowY)
                let to = CGPoint(x: child.origin.x, y: child.origin.y + child.size.height / 2)
                edges.append(LaidOutEdge(from: from, to: to))
            }

            maxX = max(maxX, origin.x + nodeWidth)
            maxY = max(maxY, origin.y + height)

            return (origin, size)
        }

        layout(root, originX: 0, top: 0)

        return GraphLayoutResult(
            nodes: laidOut,
            edges: edges,
            canvas: CGSize(width: maxX + 40, height: maxY + 40)
        )
    }
}

// MARK: - Tree builder

private enum JSONGraphTreeBuilder {
    static func build(value: JSONValue, title: String, path: [JSONPathSegment] = []) -> JSONGraphNode {
        var rows: [JSONGraphNode.Row] = []
        switch value {
        case .object(let pairs):
            for (k, v) in pairs {
                let childPath = path + [.key(k)]
                if v.isContainer {
                    rows.append(.container(label: k, summary: v.displayString, child: build(value: v, title: k, path: childPath)))
                } else {
                    rows.append(.scalar(label: k, value: v, path: childPath))
                }
            }
        case .array(let items):
            for (idx, v) in items.enumerated() {
                let label = "[\(idx)]"
                let childPath = path + [.index(idx)]
                if v.isContainer {
                    rows.append(.container(label: label, summary: v.displayString, child: build(value: v, title: label, path: childPath)))
                } else {
                    rows.append(.scalar(label: label, value: v, path: childPath))
                }
            }
        default:
            rows.append(.scalar(label: "value", value: value, path: path))
        }
        return JSONGraphNode(title: title, path: path, rows: rows)
    }
}

// MARK: - View

struct JSONGraphView: View {
    @Binding var text: String

    @State private var collapsedIds: Set<UUID> = []
    @State private var scale: CGFloat = 1.0

    private var parsedRoot: JSONValue? { JSONValueParser.parse(text) }
    private var rootNode: JSONGraphNode? {
        guard let value = parsedRoot else { return nil }
        return JSONGraphTreeBuilder.build(value: value, title: "root")
    }
    private var layout: GraphLayoutResult? {
        guard let rootNode else { return nil }
        return JSONGraphLayout.compute(root: rootNode, collapsedIds: collapsedIds)
    }

    var body: some View {
        if let layout {
            graph(for: layout)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Couldn't parse JSON")
                    .foregroundStyle(.secondary)
                Text("Switch to Pretty or Source to fix.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func graph(for layout: GraphLayoutResult) -> some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                edgesLayer(layout)
                nodesLayer(layout)
            }
            .frame(width: layout.canvas.width, height: layout.canvas.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: layout.canvas.width * scale,
                height: layout.canvas.height * scale
            )
            .padding(20)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .overlay(alignment: .bottomTrailing) { zoomControls }
    }

    private func edgesLayer(_ layout: GraphLayoutResult) -> some View {
        Canvas { context, _ in
            for edge in layout.edges {
                var path = Path()
                let dx = edge.to.x - edge.from.x
                let cp1 = CGPoint(x: edge.from.x + dx * 0.5, y: edge.from.y)
                let cp2 = CGPoint(x: edge.to.x - dx * 0.5, y: edge.to.y)
                path.move(to: edge.from)
                path.addCurve(to: edge.to, control1: cp1, control2: cp2)
                context.stroke(
                    path,
                    with: .color(Color.secondary.opacity(0.55)),
                    lineWidth: 1.2
                )
            }
        }
        .frame(width: layout.canvas.width, height: layout.canvas.height)
        .allowsHitTesting(false)
    }

    private func nodesLayer(_ layout: GraphLayoutResult) -> some View {
        ForEach(layout.nodes) { laidOut in
            JSONGraphNodeCard(
                model: laidOut.model,
                isCollapsed: collapsedIds.contains(laidOut.id),
                onToggleCollapse: {
                    if collapsedIds.contains(laidOut.id) {
                        collapsedIds.remove(laidOut.id)
                    } else {
                        collapsedIds.insert(laidOut.id)
                    }
                },
                onEditScalar: { path, newValue in
                    commitScalarEdit(at: path, newValue: newValue)
                }
            )
            .frame(width: laidOut.size.width, height: laidOut.size.height)
            .position(
                x: laidOut.origin.x + laidOut.size.width / 2,
                y: laidOut.origin.y + laidOut.size.height / 2
            )
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { scale = max(0.4, scale - 0.1) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Text("\(Int(scale * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44)
            Button { scale = min(2.0, scale + 0.1) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            Button { scale = 1.0 } label: {
                Image(systemName: "1.magnifyingglass")
            }
            .help("Reset zoom")
        }
        .buttonStyle(.borderless)
        .padding(RookerySpacing.sm)
        .rookeryGlassSurface(cornerRadius: 8)
        .padding(RookerySpacing.md)
    }

    private func commitScalarEdit(at path: [JSONPathSegment], newValue: JSONValue) {
        guard let root = parsedRoot else { return }
        let updated = root.setting(newValue, at: path)
        text = JSONValueSerializer.serialize(updated, pretty: true)
    }
}

// MARK: - Node card

private struct JSONGraphNodeCard: View {
    let model: JSONGraphNode
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onEditScalar: ([JSONPathSegment], JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.rows) { row in
                        rowView(row)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onToggleCollapse) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            Text(model.title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.secondary)
            Spacer()
            if isCollapsed && !model.rows.isEmpty {
                Text("\(model.rows.count) row\(model.rows.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
    }

    @ViewBuilder
    private func rowView(_ row: JSONGraphNode.Row) -> some View {
        switch row {
        case .scalar(_, let label, let value, let path):
            ScalarRowView(label: label, value: value, path: path, onCommit: onEditScalar)
        case .container(_, let label, let summary, _):
            HStack {
                Text(label + ":")
                    .font(.system(.caption, design: .monospaced))
                Text(summary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: JSONGraphLayout.rowHeight)
        }
    }
}

// MARK: - Editable scalar row

private struct ScalarRowView: View {
    let label: String
    let value: JSONValue
    let path: [JSONPathSegment]
    let onCommit: ([JSONPathSegment], JSONValue) -> Void

    @State private var isEditing = false
    @State private var draftText: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label + ":")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
            if isEditing {
                editor
            } else {
                display
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: JSONGraphLayout.rowHeight)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var display: some View {
        switch value {
        case .bool(let b):
            Toggle("", isOn: Binding(
                get: { b },
                set: { newValue in onCommit(path, .bool(newValue)) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        default:
            Text(value.displayString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color(for: value))
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) { beginEditing() }
                .help("Double-click to edit")
        }
    }

    @ViewBuilder
    private var editor: some View {
        TextField("", text: $draftText, onCommit: commit)
            .font(.system(.caption, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)
            .onAppear {
                draftText = rawDraft
            }
        Button { commit() } label: { Image(systemName: "checkmark") }
            .buttonStyle(.borderless)
        Button { isEditing = false } label: { Image(systemName: "xmark") }
            .buttonStyle(.borderless)
    }

    private var rawDraft: String {
        switch value {
        case .string(let s): return s              // edit without quotes
        case .integer(let i): return "\(i)"
        case .number(let n): return "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        default: return value.displayString
        }
    }

    private func beginEditing() {
        // Booleans flip via the toggle — no edit mode.
        if case .bool = value { return }
        // Null stays null (typing changes nothing); skip for v0.0.9.
        if case .null = value { return }
        draftText = rawDraft
        isEditing = true
    }

    private func commit() {
        let newValue: JSONValue = parse(draftText, current: value)
        isEditing = false
        if newValue != value {
            onCommit(path, newValue)
        }
    }

    /// Parses the user's draft into a JSONValue with the same type as the
    /// original. Strings remain strings; numbers parse if valid. Falls back
    /// to keeping the original value on parse failure.
    private func parse(_ raw: String, current: JSONValue) -> JSONValue {
        switch current {
        case .string:
            return .string(raw)
        case .integer:
            if let i = Int64(raw) { return .integer(i) }
            if let d = Double(raw) { return .number(d) }
            return current
        case .number:
            if let d = Double(raw) { return .number(d) }
            if let i = Int64(raw) { return .integer(i) }
            return current
        case .bool:
            if raw.lowercased() == "true" { return .bool(true) }
            if raw.lowercased() == "false" { return .bool(false) }
            return current
        case .null:
            return current
        default:
            return current
        }
    }

    private func color(for value: JSONValue) -> Color {
        switch value {
        case .string: return .green
        case .integer, .number: return .orange
        case .bool: return .purple
        case .null: return .gray
        default: return .primary
        }
    }
}
