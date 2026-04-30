import SwiftUI
import AppKit

// MARK: - Node model

struct JSONGraphNode: Identifiable {
    let id = UUID()
    let title: String                          // e.g. "root", "fruits[0]", "details"
    let scalars: [(key: String, value: String)]
    let containers: [(key: String, summary: String, child: JSONGraphNode)]

    /// Pre-computed once during parse, used for layout.
    var rowCount: Int { scalars.count + containers.count }
}

// MARK: - Parsing

private enum JSONGraphParser {
    static func parse(_ raw: String) -> JSONGraphNode? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return nil }
        return node(from: object, title: "root")
    }

    private static func node(from value: Any, title: String) -> JSONGraphNode {
        var scalars: [(String, String)] = []
        var containers: [(String, String, JSONGraphNode)] = []

        if let dict = value as? [String: Any] {
            for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
                switch v {
                case let nested as [String: Any]:
                    let summary = "{\(nested.count) keys}"
                    containers.append((k, summary, node(from: nested, title: k)))
                case let arr as [Any]:
                    let summary = "[\(arr.count) item\(arr.count == 1 ? "" : "s")]"
                    containers.append((k, summary, node(from: arr, title: k)))
                default:
                    scalars.append((k, scalarString(v)))
                }
            }
        } else if let arr = value as? [Any] {
            for (idx, v) in arr.enumerated() {
                let key = "[\(idx)]"
                switch v {
                case let nested as [String: Any]:
                    let summary = "{\(nested.count) keys}"
                    containers.append((key, summary, node(from: nested, title: key)))
                case let inner as [Any]:
                    let summary = "[\(inner.count) item\(inner.count == 1 ? "" : "s")]"
                    containers.append((key, summary, node(from: inner, title: key)))
                default:
                    scalars.append((key, scalarString(v)))
                }
            }
        } else {
            scalars.append(("value", scalarString(value)))
        }

        return JSONGraphNode(title: title, scalars: scalars, containers: containers)
    }

    private static func scalarString(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let s = value as? String { return "\"\(s)\"" }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber { return "\(n)" }
        return String(describing: value)
    }
}

// MARK: - Layout

private struct LaidOutNode: Identifiable {
    let id: UUID
    let model: JSONGraphNode
    var origin: CGPoint
    let size: CGSize
}

private struct LaidOutEdge {
    let from: CGPoint           // right-center of parent's container row
    let to: CGPoint             // left-center of child node
    let label: String           // the key or summary on the parent side
}

private struct GraphLayoutResult {
    let nodes: [LaidOutNode]
    let edges: [LaidOutEdge]
    let canvas: CGSize
}

private enum JSONGraphLayout {
    static let nodeWidth: CGFloat = 260
    static let rowHeight: CGFloat = 26
    static let headerHeight: CGFloat = 30
    static let nodePadding: CGFloat = 8
    static let horizontalGap: CGFloat = 80
    static let verticalGap: CGFloat = 16

    static func compute(root: JSONGraphNode) -> GraphLayoutResult {
        var laidOut: [LaidOutNode] = []
        var edges: [LaidOutEdge] = []

        // Phase 1: each node's vertical extent depends on its subtree height.
        // We do a recursive layout: for each node, lay out its container
        // children stacked vertically to its right, then position this node
        // at the vertical center of its children's combined extent.

        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        func layout(_ node: JSONGraphNode, originX: CGFloat, top: CGFloat) -> (id: UUID, origin: CGPoint, size: CGSize, rowCenters: [CGFloat], childCenters: [CGFloat]) {
            let height = headerHeight + nodePadding * 2 + CGFloat(node.rowCount) * rowHeight
            let size = CGSize(width: nodeWidth, height: height)

            let childOriginX = originX + nodeWidth + horizontalGap
            var childTop = top
            var childResults: [(id: UUID, origin: CGPoint, size: CGSize)] = []

            for (_, _, child) in node.containers {
                let result = layout(child, originX: childOriginX, top: childTop)
                childResults.append((result.id, result.origin, result.size))
                let consumed = max(result.size.height, height)
                childTop += consumed + verticalGap
            }

            let nodeY: CGFloat
            if let first = childResults.first, let last = childResults.last {
                let mid = ((first.origin.y) + (last.origin.y + last.size.height)) / 2
                nodeY = mid - height / 2
            } else {
                nodeY = top
            }

            let origin = CGPoint(x: originX, y: nodeY)

            // Compute row centers (in absolute coords) for this node so edges
            // can connect from the correct row.
            var rowCenters: [CGFloat] = []
            let firstScalarY = origin.y + headerHeight + nodePadding + rowHeight / 2
            for i in 0..<node.scalars.count {
                rowCenters.append(firstScalarY + CGFloat(i) * rowHeight)
            }
            let firstContainerY = firstScalarY + CGFloat(node.scalars.count) * rowHeight
            var containerCenters: [CGFloat] = []
            for i in 0..<node.containers.count {
                containerCenters.append(firstContainerY + CGFloat(i) * rowHeight)
            }

            laidOut.append(LaidOutNode(id: node.id, model: node, origin: origin, size: size))

            for (idx, child) in childResults.enumerated() {
                let parentRowY = containerCenters[idx]
                let from = CGPoint(x: origin.x + nodeWidth, y: parentRowY)
                let to = CGPoint(x: child.origin.x, y: child.origin.y + child.size.height / 2)
                let label = node.containers[idx].key
                edges.append(LaidOutEdge(from: from, to: to, label: label))
            }

            maxX = max(maxX, origin.x + nodeWidth)
            maxY = max(maxY, origin.y + height)

            return (id: node.id, origin: origin, size: size, rowCenters: rowCenters, childCenters: containerCenters)
        }

        _ = layout(root, originX: 0, top: 0)

        return GraphLayoutResult(
            nodes: laidOut,
            edges: edges,
            canvas: CGSize(width: maxX + 40, height: maxY + 40)
        )
    }
}

// MARK: - View

struct JSONGraphView: View {
    let raw: String

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    private var layout: GraphLayoutResult? {
        guard let root = JSONGraphParser.parse(raw) else { return nil }
        return JSONGraphLayout.compute(root: root)
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
        ForEach(layout.nodes) { node in
            JSONGraphNodeCard(model: node.model)
                .frame(width: node.size.width, height: node.size.height)
                .position(
                    x: node.origin.x + node.size.width / 2,
                    y: node.origin.y + node.size.height / 2
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
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }
}

// MARK: - Node card

private struct JSONGraphNodeCard: View {
    let model: JSONGraphNode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.scalars.enumerated()), id: \.offset) { _, pair in
                    scalarRow(key: pair.key, value: pair.value)
                }
                ForEach(Array(model.containers.enumerated()), id: \.offset) { _, item in
                    containerRow(key: item.key, summary: item.summary)
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

    private func scalarRow(key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key + ":")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(scalarColor(for: value))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: JSONGraphLayout.rowHeight)
    }

    private func containerRow(key: String, summary: String) -> some View {
        HStack {
            Text(key + ":")
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

    private func scalarColor(for value: String) -> Color {
        if value == "null" { return .gray }
        if value == "true" || value == "false" { return .purple }
        if value.hasPrefix("\"") { return .green }
        if Double(value) != nil { return .orange }
        return .primary
    }
}
