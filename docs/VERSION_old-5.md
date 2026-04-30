# Agent Helm — Version

**Current:** `0.0.7` (real markdown rendering + image/PDF/JSON preview)

## Changelog

### 0.0.7 — 2026-04-30
**Fix the markdown preview + broaden file-type support.**

The 0.0.6 markdown preview was using `AttributedString(markdown:)` with `interpretedSyntax: .inlineOnlyPreservingWhitespace`, which only handled inline syntax (bold/italic/links/code spans). Block-level structure (headings, code blocks, lists, tables) collapsed into a single line — clearly broken when previewing TESTING.md.

**Replaced with [MarkdownUI 2.4.1](https://github.com/gonzalezreal/swift-markdown-ui)** (added as SwiftPM dependency, GitHub theme). Real block-level rendering: headings sized correctly, code blocks preserve indentation and use monospaced font, lists nest, tables render as tables, block quotes indent, links are clickable. Live preview against the in-memory edit buffer is unchanged.

**New per-file-kind dispatch** — `PreviewableFileKind` enum (`markdown / json / image / pdf / sourceText`) maps the file extension to the right preview/editor:

| Kind | Extensions | Preview | Source | Editable |
|---|---|---|---|---|
| Markdown | `.md`, `.markdown`, `.mdown`, `.mkd` | MarkdownUI render | Plain TextEditor | Yes |
| JSON | `.json` | Pretty-printed (sorted keys, 2-space indent) | Raw TextEditor | Yes |
| Image | `.png`, `.jpg`/`.jpeg`, `.gif`, `.heic`/`.heif`, `.tiff`, `.bmp`, `.webp`, `.ico`, `.icns` | `NSImage` scaled-to-fit | n/a | No |
| PDF | `.pdf` | PDFKit `PDFView` continuous-vertical | n/a | No |
| Source text | everything else UTF-8 | n/a | Monospaced TextEditor | Yes |

Images and PDFs hit the preview-only path: bytes loaded into `FileBufferState.image(data:)` / `.pdf(data:)`, no UTF-8 decode attempted. Save / Discard buttons hide for non-editable kinds. The Preview/Source segmented toggle only appears when both modes meaningfully differ (markdown, JSON).

**State changes:**
- `FileBufferState` adds `.image(data: Data)` and `.pdf(data: Data)` cases.
- `RemoteFileEntry` gains `previewableKind` extension via the new `PreviewableFileKind` enum.
- `SessionState.openFile` dispatches on `previewableKind` after the size check.

**New views:**
- `MarkdownPreviewView` — wraps MarkdownUI's `Markdown` with a scroll view and the GitHub theme.
- `JSONPreviewView` — uses `JSONSerialization` to pretty-print with sorted keys; falls back to raw text if not valid JSON.
- `ImagePreviewView` — `Image(nsImage:)` in a scrollable container; placeholder if the image format isn't decodable.
- `PDFPreviewView` — `NSViewRepresentable` wrapping `PDFView`.

### 0.0.6 — 2026-04-30
- Read & edit any UTF-8 text file. Markdown Preview/Source toggle. Save/Discard, Cmd+S, dirty indicator. (Markdown render quality fixed in 0.0.7.)

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
