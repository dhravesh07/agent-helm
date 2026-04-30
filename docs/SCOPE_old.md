# Agent Helm — Scope

## What it is
A native macOS client for managing AI coding agents (Claude Code, OpenClaude, OpenCode, Aider-as-daemon, etc.) — whether they run **locally on the same Mac** or on **remote Linux servers**. One pane of glass for the operator side of self-hosted agent setups.

## Connection kinds (v0.0.4+)
A host profile is one of:
- **Local** — points at a folder on the current Mac (e.g., `~/.claude`, an `openclaude` directory, any project root). No network, no auth; backed by `FileManager`.
- **Remote (SSH)** — connects to a Linux server over SSH; backed by Citadel SFTP.

Both kinds use the same browser/viewer UI; the file backend is abstracted behind `RemoteFileService`.

## In scope (v0–v1)

### Connectivity
- SSH connections to one or more Linux hosts (password, key, SSH agent forwarding).
- Multi-host management with quick switcher.
- Credentials in macOS Keychain.

### File browsing & editing
- Browse the remote filesystem from a configurable root per host.
- Live `.md` editing — markdown viewer + editor with syntax highlighting and split preview.
- Real-time updates when files change on the remote (SFTP polling for v0.1; inotify-over-SSH bridge in v0.5+).
- Save-back over SFTP with conflict detection.

### Database inspection
- Read-only browser for SQLite databases on the remote, transferred lazily over SFTP.
- Schema view, table view, query runner (read-only).
- Common agent DBs treated as first-class (Claude Code transcript stores, vector indices).

### Cron management
- List the user's crontab on the remote (`crontab -l`).
- Edit and validate cron entries with a friendly schedule picker.
- Surface recent run history from system mail spool / configured log files.
- Trigger a one-shot run of any cron entry on demand.

### Skill / agent lifecycle
- Install skills by dropping files into the agent's expected location (`~/.claude/skills/`, etc.).
- Browse installed skills, see their metadata.
- Spawn a new agent process via a configurable command per host profile (`tmux new -s ... claude ...`, etc.).
- Tail the agent's output / logs.

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

## Assumptions
- The remote server runs systemd or has cron available.
- The user has SSH access and basic shell familiarity.
- Agent state lives mostly in the user's home dir on the remote (`~/.claude/`, `~/.config/aider/`, etc.).
