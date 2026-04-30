# Agent Helm — Version

**Current:** `0.0.10` (double-click navigation)

## Changelog

### 0.0.10 — 2026-04-30
**File browser navigation matches Finder semantics.** Single-click on a row now just highlights it; double-click (or Enter on the highlighted row) navigates into a folder or opens a file. The previous single-click-to-navigate behavior felt aggressive — folders fired before the user could even read the name.

- `FileBrowserView` adds `@State private var highlightedId: RemoteFileEntry.ID?` for the list selection. The `List` selection binding now points at this state instead of triggering navigation.
- `.onTapGesture(count: 2)` on each row activates it (folder → navigate, file → open).
- `.onKeyPress(.return)` on the list activates the highlighted row, matching macOS keyboard expectations.
- Highlight resets when the directory changes.

### 0.0.9 — 2026-04-30
**Four big items, all delivered.**

#### 1. Workspace paths refactor
The single `HostProfile.rootPath: String` is gone. A host now has an ordered list of `Workspace { id, name, path }`. The user adds one workspace per area they want to inspect (Skills, project root, agent state, notes, …) — no path is hardcoded anywhere in the app.

- New `Models/Workspace.swift`.
- `HostProfile.workspaces: [Workspace]` (defaults to a single `Root` workspace at `~`).
- Custom `Codable` migration: any v0.0.3–v0.0.8 stored profile that has only the legacy `rootPath` field decodes into a single workspace named `Root` with that path.
- `HostFormView` gets a workspace editor (per-row name + path + folder picker for local + delete; Add button at the bottom). Minimum one workspace; can't delete the last one.
- `FileBrowserView` shows a segmented workspace picker in the header when a host has 2+ workspaces. Switching workspaces resets the selected file and re-lists.
- `HostListView` subtitle: shows the workspace path for single-workspace local hosts, or "N workspaces" otherwise.
- `LocalFileService.connect` no longer pre-validates the configured root — the first `listDirectory` call surfaces a missing path with a clear error, so a missing one workspace doesn't block the others.

#### 2. Sleep/wake reconnect resilience
The app no longer lies about being connected after the laptop wakes from sleep.

- New `ConnectionStatus` case: `.reconnecting`. Toolbar shows a spinner; the file browser shows a "Reconnecting after sleep/wake…" pane.
- `SessionState` subscribes to `NSWorkspace.didWakeNotification` and `NSWorkspace.willSleepNotification`. On wake, remote sessions tear down and reconnect.
- `NWPathMonitor` watches network path; when connectivity flips from unsatisfied → satisfied, remote sessions auto-reconnect (a clean transition, not on every WiFi roam).
- New `SessionState.cancelLifecycleObservers()` for explicit teardown.
- Local sessions are exempt from network-driven reconnects — but a missing path still surfaces on the next listing operation.

#### 3. Syntax highlighting (regex-based, no JS runtime)
Source-mode editor now colors keywords, strings, numbers, comments, and symbols. Pure Swift, no JavaScript runtime, no new SwiftPM dependency. Languages bundled: **Swift, Python, JavaScript/TypeScript, JSON, YAML, TOML, Shell, Ruby, Go, Rust** (10 specs, ~200 lines of `LanguageSpec` definitions).

- New `Models/SyntaxHighlighter.swift` defines `SyntaxToken`, `SyntaxRule`, `LanguageSpec`, and a `SyntaxLanguages` registry mapping file extensions → spec.
- `LineNumberedTextEditor` accepts a `languageSpec: LanguageSpec?`. On text-change, a 200ms debounced task re-applies foreground-color attributes via `NSTextStorage`'s edit transaction. Selection survives. The font is preserved across re-highlights.
- Token colors use the system palette so they adapt to light/dark appearance.
- Each rule is a precompiled `NSRegularExpression`; later rules win on overlap, so e.g. comments override "looks like a keyword inside a comment".

#### 4. JSON graph: collapsible nodes + edit-in-place
The Graph view in JSON files is now interactive.

- Each node card has a chevron toggle. **Collapsed** = title-only header, no rows; subtree below is hidden in the layout. State lives in `JSONGraphView`'s `@State collapsedIds: Set<UUID>`.
- Layout is recomputed each render against the current collapsed set; collapsed nodes shrink to a fixed height (32pt) and their children disappear.
- **Scalar values are editable.** Double-click a string / number value → it becomes a `TextField`; commit (Enter or check button) writes the new value back through a structured JSON path.
- **Booleans flip via a `Toggle`** — no edit mode, just click. Type-preserving: a number stays a number, a string stays a string. Failed parses keep the original.
- Internally we now have a real `JSONValue` enum (object/array/string/number/integer/bool/null) with a recursive `setting(_:at:)` for path-based mutation, plus a serializer that round-trips back to pretty-printed JSON. The graph view binds the file's `editText`, so edits flow through the same `isDirty` / Save pipeline as any other text edit.
- One known limitation: object key order isn't preserved through `JSONSerialization` parsing — round-tripped JSON has alphabetical keys. Documented as accepted v0.0.9 behavior; a streaming parser that preserves order is a future tweak.

**State / model changes:**
- `ConnectionStatus.reconnecting` (new case).
- `HostProfile.workspaces: [Workspace]` (replaces `rootPath`); custom Codable migration.
- `SessionState`: tracks `currentWorkspaceId`, exposes `currentWorkspace`, has `switchWorkspace(_:)` and `reconnect()`. Subscribes to NSWorkspace + NWPathMonitor.

### 0.0.8 — 2026-04-30
- XML support, line numbers, JSON Graph view (initial — read-only).

### 0.0.7 — 2026-04-30
- MarkdownUI 2.4.1, image preview, PDF preview, JSON pretty-print.

### 0.0.6 — 2026-04-30
- Read & edit any UTF-8 text file. Markdown Preview/Source toggle.

### 0.0.5 — 2026-04-30
- Auto-connect on host selection.

### 0.0.4 — 2026-04-30
- Local-Mac connection kind alongside remote SSH.

### 0.0.3 — 2026-04-30
- First functional slice.

### 0.0.2 — 2026-04-30
- Xcode project via xcodegen.

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
