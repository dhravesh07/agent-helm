# Agent Helm — Version

**Current:** `0.0.8` (XML support + line numbers + JSON Graph view)

## Changelog

### 0.0.8 — 2026-04-30
**Three asks, all delivered:**

1. **XML support.** New file kind covering `.xml`, `.plist`, `.xib`, `.storyboard`, `.rss`, `.atom`, `.svg`. Modes: **Preview / Source**. Preview pretty-prints via Foundation's `XMLDocument` with `[.nodePrettyPrint, .nodeCompactEmptyElement]`; falls back to raw text on parse failure. Edit happens in Source mode and writes the raw bytes back unchanged.

2. **Line numbers in the source editor.** Replaced SwiftUI's `TextEditor` (no gutter, no layout-manager access) with `LineNumberedTextEditor` — an `NSViewRepresentable` wrapping `NSTextView` inside `NSScrollView` with a custom `NSRulerView` (`LineNumberRulerView`) drawing numbers in `monospacedDigitSystemFont`. Lazy redraw: gutter invalidates only on text-change and bounds-change notifications. Selection is preserved across `updateNSView` cycles. Auto-correction / smart-quotes / link-detection all disabled (these are wrong for source code). Find-bar enabled. Sets up the foundation for syntax highlighting later — that's a token-coloring layer on the same `NSTextView`.

3. **JSON Graph view (jsoncrack-style).** New view mode for `.json` files: **Graph**. Native SwiftUI implementation, no JS / web-view:
   - **Parse:** `JSONSerialization` → `JSONGraphNode` tree, where each node carries its inline scalar rows and its container children.
   - **Layout:** hierarchical, left-to-right. Each node sits at the vertical center of its children's combined bounding box; subtrees stack vertically with a fixed gap. Node width is fixed (260 pt); height grows with row count.
   - **Render:** ZStack of `JSONGraphNodeCard`s positioned via `.position()`, with a `Canvas` overlay drawing bezier-curve edges from a parent's container row to the child node's left edge.
   - **Zoom:** floating control in the bottom-right (-/+/100%). 40%–200% range. Panning via the parent `ScrollView`.
   - **Card design:** title bar (path component, accent-tinted), divider, then scalar rows with type-aware coloring (strings green, numbers orange, booleans purple, null gray, hex codes preserve their swatch in future), then container rows showing `key: {N keys}` / `key: [N items]` with a right-arrow indicator.
   - **Modes for JSON:** **Graph / Pretty / Source** (graph is now the default).

**File kind enum** gained `.xml`. **`FileViewMode`** gained `.graph` and `.formatted`. **`PreviewableFileKind.availableViewModes`** drives the segmented picker (per-kind, in display order). The picker auto-sizes to the number of available modes.

**Files added:**
- `Views/XMLPreviewView.swift`
- `Views/LineNumberedTextEditor.swift` (+ `LineNumberRulerView` in the same file)
- `Views/JSONGraphView.swift` (+ private parser, layout engine, and node-card view in the same file)

**Files renamed/repurposed:**
- `JSONPreviewView` is now the "Pretty" mode; the new "Graph" mode is the default for JSON.

### 0.0.7 — 2026-04-30
- MarkdownUI 2.4.1 for proper markdown rendering. Image preview (NSImage). PDF preview (PDFKit). JSON pretty-print. Per-file-kind dispatch.

### 0.0.6 — 2026-04-30
- Read & edit any UTF-8 text file. Markdown Preview/Source toggle (rendering quality fixed in 0.0.7).

### 0.0.5 — 2026-04-30
- Auto-connect on host selection. Architectural-review docs corrections.

### 0.0.4 — 2026-04-30
- Local-Mac connection kind alongside remote SSH.

### 0.0.3 — 2026-04-30
- First functional slice. SSH connect (ed25519 / RSA), SFTP file tree, markdown viewer.

### 0.0.2 — 2026-04-30
- Xcode project via xcodegen, Makefile, entitlements.

### 0.0.1 — 2026-04-30
- Initial scaffold.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- Pre-1.0: minor bumps for new features, patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.
