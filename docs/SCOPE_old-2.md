# Rookery — Scope

## What it is
**Rookery** is a Mac-native inspector for the state your AI coding agents leave behind — the markdown configs, JSON sessions, SQLite memory stores, and JSONL transcripts that pile up in `~/.claude`, `~/.config/aider`, `.openclaude/`, and your project directories. Read what your agents wrote.

It's a **state inspector**, not a chat surface, not an SSH terminal, not an agent runner.

## Connection kinds
A host profile is one of:
- **Local** — a folder on the current Mac (e.g., `~/.claude`, an `openclaude` directory, any project root). No network, no auth; backed by `FileManager`.
- **Remote (SSH)** — a Linux server. Backed by Citadel SFTP. Optional and secondary; the primary use case is local.

Both kinds use the same browser/viewer UI; the file backend is abstracted behind `RemoteFileService`. Selection auto-connects (instant for local, async for remote).

## Workspace paths
A host carries an ordered list of named **workspace paths** (`HostProfile.workspaces: [Workspace]`). Add one workspace per area you want to inspect — Skills, project root, agent state, notes. No path is hardcoded anywhere in the app; Aider's `.aider*` lives per-project, not in a home dir, so the user points at the relevant project root.

The file-browser header shows a segmented workspace picker when the host has 2+ workspaces.

## In scope (v0.1+)

### File browsing & viewing
- Browse the filesystem from one or more workspace paths per host.
- Single-click selects a row; double-click (or Enter on the highlighted row) navigates into a folder or opens a file.
- Per-file-kind preview + edit:
  - **Markdown** (`.md`, `.markdown`, `.mdown`, `.mkd`) — rendered with [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) (GitHub theme), full block support: headings, lists, code blocks, tables, block quotes, links. Modes: **Preview / Source**.
  - **JSON** (`.json`) — Modes: **Graph / Pretty / Source**. Graph view is a hierarchical node-graph rendered natively in SwiftUI (Canvas + positioned cards) with bezier edges, collapsible nodes, and edit-in-place for scalar values. Pretty view is `JSONSerialization` pretty-print with sorted keys.
  - **XML** (`.xml`, `.plist`, `.xib`, `.storyboard`, `.rss`, `.atom`, `.svg`) — Modes: **Preview / Source**. Preview pretty-prints via Foundation `XMLDocument`.
  - **Images** (`.png`, `.jpg`, `.jpeg`, `.gif`, `.heic`, `.heif`, `.tiff`, `.bmp`, `.webp`, `.ico`, `.icns`) — `NSImage`, preview-only.
  - **PDFs** (`.pdf`) — PDFKit `PDFView`, continuous-vertical scroll, preview-only.
  - **All other UTF-8 text** — code, configs, YAML, TOML, CSV, scripts, plain text — opens in the source editor.
  - **Binary** — surfaces as "Binary file — not shown".
- Source editor: `LineNumberedTextEditor` — `NSTextView` + custom `NSRulerView` gutter. Line numbers in monospaced-digit font.
- Syntax highlighting — pure-Swift regex-based highlighter. Languages: Swift, Python, JS/TS, JSON, YAML, TOML, Shell, Ruby, Go, Rust. No JS runtime. Token colors adapt to light/dark.
- 5 MB per-file cap for in-app edits.
- Save-back: Cmd+S or toolbar button. Local writes are atomic; remote writes use SFTP `[.write, .create, .truncate]`.
- Save / Discard / "Modified" indicator.

### Database inspection (v0.2.0 — implemented)
- **SQLite** read-only browser via [GRDB.swift 7.10](https://github.com/groue/GRDB.swift): file kinds `.db`, `.sqlite`, `.sqlite3`, `.db3`.
- Three modes: **Tables** (sidebar of tables + paginated row grid, 50/page), **Schema** (column list + full CREATE statement), **Query** (line-numbered SQL editor with syntax highlighting + read-only SELECT/WITH/PRAGMA/EXPLAIN runner, up to 1000 rows).
- Local: opens the file directly (read-only). Remote: SFTP-download to `~/Library/Caches/Rookery/`, opens the cached copy. Refresh button re-runs the table query; full re-download on user-triggered refresh is deferred to v0.5.
- 200 MB cap for SQLite files (separate from the 5 MB text-edit cap).
- **Agent-schema awareness** — registry skeleton in place; specific schema templates (Claude Code session DB, Aider chat history, OpenCode stores) ship as the layouts are verified against real installations.

### Transcript / log viewer (v0.3)
- **JSONL** transcript viewer — one message per row, expandable inline, role-colored, search.
- Tail mode for live logs.
- Common Claude Code session-transcript layouts known by default.

### Connection lifecycle
- `NSWorkspace` sleep/wake hooks; mark sessions as `.reconnecting` on wake; auto-reconnect.
- `NWPathMonitor` for network-restored transitions.

## Out of scope (deliberate)

| Not building | Why |
|---|---|
| Chat / prompting interface to the agent | claude.ai, claudecodeui, the agent's own TUI all do this well. |
| General SSH terminal | Termius, Tabby, Warp own this. |
| Agent runner / spawner / supervisor | ClawTab does this for local. We don't manage agent processes. |
| Cron / launchd / scheduled-task management | Claude Code has its own scheduled tasks; ClawTab has cron. Diminishing return. |
| Skill installer / marketplace | The agent ecosystem isn't standardized; this is a moving target. |
| Cloud orchestration | No Kubernetes, no AWS console. |
| Windows / Linux client | Mac-only. |
| Hosting / SaaS | Local app, no Rookery cloud. |
| Multi-user / RBAC | Single-operator tool. |

## Editing model
Files are editable by default. The "Modified" indicator + Save / Discard pair handles the simple case. **Lock-for-Editing** with multi-signal conflict detection (mtime + size + SHA-256 + git status) is added when contention with a live agent matters in practice — likely once the DB / transcript inspection lands.

## Tech stack
- **Language:** Swift 5.9+
- **UI:** SwiftUI (`NavigationSplitView` three-pane), `@Observable` for state.
- **Minimum target:** macOS 14 (Sonoma)
- **SSH:** [Citadel 0.12.1](https://github.com/orlandos-nl/Citadel)
- **Markdown:** [MarkdownUI 2.4.1](https://github.com/gonzalezreal/swift-markdown-ui)
- **SQLite (v0.2):** [GRDB.swift](https://github.com/groue/GRDB.swift)
- **Build:** Xcode project generated from `src/project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen) + `Package.swift` for fast CLI iteration.

## Assumptions
- Most users run agents locally on a Mac. SSH is for the VPS / home-server case, not the default.
- Agents store the interesting state on disk: markdown configs, JSON sessions, SQLite memory, JSONL transcripts. We read those files directly.
- The user is curious about *what the agent has been doing*, not interested in *prompting it from another surface*.
