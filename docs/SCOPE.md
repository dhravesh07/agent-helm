# Agent Helm — Scope

## What it is
A native macOS client for managing AI coding agents (Claude Code, OpenClaude, OpenCode, Aider-as-daemon, etc.) — whether they run **locally on the same Mac** or on **remote Linux servers**. One pane of glass for the operator side of self-hosted agent setups.

## Connection kinds (v0.0.4+)
A host profile is one of:
- **Local** — points at a folder on the current Mac (e.g., `~/.claude`, an `openclaude` directory, any project root). No network, no auth; backed by `FileManager`.
- **Remote (SSH)** — connects to a Linux server over SSH; backed by Citadel SFTP.

Both kinds use the same browser/viewer UI; the file backend is abstracted behind `RemoteFileService`. Selection auto-connects (instant for local, async for remote) — the user does not click a "Connect" button to use a host they just selected.

## Workspace paths (v0.0.9 — implemented)
Agent Helm does **not** hardcode locations like `~/.claude/skills/`. Each host profile carries an ordered list of named **workspace paths** (`HostProfile.workspaces: [Workspace]`):

```
[
  { name: "Skills",        path: "~/.claude/skills" },
  { name: "Project notes", path: "~/repos/agent-helm" },
  { name: "Aider chats",   path: "~/repos/agent-helm/.aider.chat.history.md" }
]
```

The file-browser header shows a segmented workspace picker when the host has 2+ workspaces. Add, rename, or delete via the host form. **Discovery presets** (Claude Code, OpenClaude, Aider, OpenCode) for one-click population of common paths land in v1.0 onboarding; today the user types or picks paths.

Aider scatters `.aider*` files in each project directory, so the user is expected to point at the relevant project root, not a fixed home-dir location. This is exactly what the workspace abstraction enables — no path is sacred.

`Codable` migration: v0.0.3–v0.0.8 stored profiles (single `rootPath`) decode cleanly into a one-workspace list named `Root`.

## In scope (v0–v1)

### Connectivity
- SSH connections to one or more Linux hosts (password, key, SSH agent forwarding).
- Multi-host management with quick switcher.
- Credentials in macOS Keychain.

### File browsing & editing
- Browse the remote filesystem from one or more **workspace paths** per host (see "Workspace paths" below).
- **Per-file-kind preview + edit** (v0.0.8):
  - **Markdown** (`.md`, `.markdown`, `.mdown`, `.mkd`) — rendered with [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) (GitHub theme), full block support: headings, lists, code blocks, tables, block quotes, links. Modes: **Preview / Source**.
  - **JSON** (`.json`) — Modes: **Graph / Pretty / Source**. Graph view is a jsoncrack-style hierarchical node-graph rendered natively in SwiftUI (Canvas + positioned cards) with bezier edges between parent rows and child nodes, and a zoom control. Pretty view is `JSONSerialization` pretty-print with sorted keys. Source is the raw text editor.
  - **XML** (`.xml`, `.plist`, `.xib`, `.storyboard`, `.rss`, `.atom`, `.svg`) — Modes: **Preview / Source**. Preview pretty-prints via Foundation `XMLDocument` with `[.nodePrettyPrint, .nodeCompactEmptyElement]`.
  - **Images** (`.png`, `.jpg`, `.jpeg`, `.gif`, `.heic`, `.heif`, `.tiff`, `.bmp`, `.webp`, `.ico`, `.icns`) — rendered via `NSImage`; preview-only, no edit.
  - **PDFs** (`.pdf`) — rendered via PDFKit's `PDFView` with continuous-vertical scroll; preview-only, no edit.
  - **All other UTF-8 text** — code, configs, YAML, TOML, CSV, scripts, plain text — opens in the source editor.
  - **Binary** (anything that fails UTF-8 decode and isn't an image/PDF) — surfaces as "Binary file — not shown".
- **Source editor** (v0.0.8+) is `LineNumberedTextEditor` — `NSTextView` + custom `NSRulerView` gutter showing line numbers in monospaced-digit font. Replaces SwiftUI's `TextEditor`, which has no gutter and limited control over layout.
- **Syntax highlighting** (v0.0.9+) — pure-Swift regex-based highlighter (`SyntaxHighlighter` + `LanguageSpec` registry). Languages: Swift, Python, JS/TS, JSON, YAML, TOML, Shell, Ruby, Go, Rust. No JavaScript runtime, no new SwiftPM dependency. Token colors adapt to light/dark via system palette. Re-highlight is debounced 200ms on text change. Adding a language is a single `LanguageSpec` literal.
- 5 MB per-file cap for in-app edits; larger files surface as "too large" with size shown. The cap is configurable in v0.9+.
- Save-back uses Cmd+S or the toolbar button. Local writes are atomic; remote writes use SFTP `[.write, .create, .truncate]`.
- **Lock-for-Editing model with multi-signal conflict detection** (mtime + size + SHA-256, plus git-aware diff in repos) is the v0.1-finalization layer for use against an active agent — see "Editing model" below. The current release ships with a Save / Discard pair and a "Modified" indicator; the lock + 3-way diff land before v0.1.0.
- Real-time updates when files change on the remote (SFTP polling for v0.2; inotify-over-SSH bridge in v0.5+).

### Database inspection
- Read-only browser for SQLite databases on the remote, transferred lazily over SFTP.
- Schema view, table view, query runner (read-only).
- Common agent DBs treated as first-class (Claude Code transcript stores, vector indices).

### Cron management
- List the user's crontab on the remote (`crontab -l`).
- Edit and validate cron entries with a friendly schedule picker.
- Surface recent run history from system mail spool / configured log files.
- Trigger a one-shot run of any cron entry on demand.

### Connection lifecycle (resilience)
A Mac client over SSH must survive sleep/wake, network changes, and idle disconnects without the UI lying about its state.
- Subscribe to `NSWorkspace.didWakeNotification` and `NSWorkspace.willSleepNotification`; on wake, mark all SSH sessions as needing reconnection and run a quick health-check before any subsequent operation.
- Subscribe to `NWPathMonitor` for network path changes; transition cleanly when the user moves between Wi-Fi networks or VPN states.
- Periodic keep-alive ping (or SSH server-alive) on each session; on failure, transition to `.disconnected` (or `.reconnecting`) and surface in the toolbar — never silently fail the next user action.
- Auto-reconnect with exponential backoff on transient failures; ask the user before reconnecting if the disconnect was clean.
- Local-mode hosts are exempt — they're filesystem-only — but the same lifecycle hooks apply for consistency (e.g., re-validating that the configured folder still exists after a sleep cycle, in case external storage was unmounted).

### Skill / agent lifecycle
**Install / inspect:**
- Install skills by SFTP-pushing a directory or zip into a configured "Skills" workspace path (the user names it; default discovery presets exist for Claude / Aider / OpenCode but nothing is hardcoded).
- Browse installed skills, see their metadata.

**Run / supervise (configurable per host):**
- Spawn a new agent process via a per-profile command template. Built-in supervisor profiles for **tmux**, **screen**, **systemd-run --user**, **nohup**, and **plain background `&`**. Default is whatever the user's shell history or installed binaries suggest, not a baked-in tmux assumption.
- Tail / attach uses the same supervisor profile (e.g., `tmux attach`, `journalctl --user -fu <unit>`, `tail -f` of a configured log path).

**Stop / uninstall / prune (operator hygiene — added with the install/spawn features, not a v1.0 afterthought):**
- Stop a running agent (kill the supervisor unit; SIGTERM with grace period, then SIGKILL).
- Uninstall a skill (remove its directory and any registered metadata file).
- Prune resources: clear / archive old agent transcripts, vector indices, and SQLite WAL files; per-host disk-use summary so the user can see what's eating space before pruning.

## Out of scope

- **Running agents themselves.** Agent Helm is the operator/control surface — viewing and editing the agent's state files, schedules, DBs, and skills. Use Claude Code, Cursor, or your editor of choice to actually run the agent. Local-mode just means we can browse the Mac's own filesystem; we don't host the agent process.
- **General-purpose terminal.** Termius, Tabby, and friends do this well — Agent Helm's terminal pane (if any) is a fallback, not the headline feature.
- **Cloud orchestration.** No Kubernetes, no AWS console. Agent Helm assumes long-running boxes the user owns.
- **Windows / Linux client.** Mac-only. Cross-platform may be a v2+ conversation.
- **Hosting / paid SaaS.** This is a local app; there is no Agent Helm cloud.

## Non-goals (deliberate exclusions)

- Replacing the agent's own UI (e.g., Claude Code's TUI). Agent Helm complements; it doesn't reimplement.
- Multi-user / team features (RBAC, audit log streaming). Single-operator tool.
- Plugin marketplace. Skills are installed by file copy; discovery is the user's problem for now.

## Tech stack
- **Language:** Swift 5.9+
- **UI:** SwiftUI (`NavigationSplitView` three-pane), `@Observable` for state.
- **Minimum target:** macOS 14 (Sonoma)
- **SSH:** [Citadel 0.12.1](https://github.com/orlandos-nl/Citadel) (pure Swift, depends on swift-nio + swift-nio-ssh + swift-crypto). Wrapped behind an `actor SSHService`.
- **SQLite:** [GRDB.swift](https://github.com/groue/GRDB.swift) (added when SQLite browser lands in v0.0.4).
- **Markdown:** Foundation's `AttributedString(markdown:)` for view; custom `NSTextView` wrapper for edit (added in v0.0.4); consider [Splash](https://github.com/JohnSundell/Splash) for code-block highlighting later.
- **Build:** Xcode project (canonical, generated from `src/project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen)) + `Package.swift` (kept for fast CLI iteration). The `.xcodeproj` is gitignored; contributors regenerate it with `make bootstrap` after cloning.
- **Testing:** XCTest, ViewInspector for SwiftUI views.

## Editing model (v0.0.5+)
Files are **read-only by default**. To edit, the user explicitly clicks **Lock for Editing** on a specific file, which:
1. Records the file's mtime, size, and SHA-256 at lock time as the integrity baseline.
2. Optionally signals the agent to pause writes to that path (per-supervisor-profile hook; tmux: send a configurable command; systemd: `systemctl --user stop`; nohup: `kill -STOP`; configurable per host).
3. If the directory is a git repo, captures `git status` output as a second-axis check.

**Save flow:** before write-back, re-read the remote file's mtime/size/SHA. If any drift, surface a 3-way diff (last-locked vs. current-remote vs. user-edited) — never silently overwrite. mtime alone is not a sufficient signal because filesystem resolutions vary and agents like Aider rewrite files multiple times per second; the multi-signal check + lock-for-editing model is the real guarantee.

The "explicit lock" cost is one click; the safety it buys is large in the presence of a live agent. This is the operator-tool default, not the IDE default.

## Assumptions
- The user has SSH access and basic shell familiarity (for remote hosts).
- Process supervision on remote hosts is one of: tmux, screen, systemd-run --user, nohup, or plain background `&`. The user picks one per host profile; the spawn / tail / stop primitives use that profile. **There is no implicit assumption that tmux is running.**
- For local hosts, the user has the agent installed somewhere (`claude`, `aider`, etc.); spawn/tail still goes through the configured supervisor profile (often `tmux` on macOS, but `nohup` is supported).
- Cron is available on remote hosts (`crontab` binary). On local-mode macOS hosts, cron features may degrade — `launchd` integration is a stretch goal.
- Agent state location is **not** assumed. It's configured per host as workspace paths (see above).
