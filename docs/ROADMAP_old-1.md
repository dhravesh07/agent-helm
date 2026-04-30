# Rookery — Roadmap

Versions follow SemVer. Project pivoted from "Agent Helm — control plane" to "Rookery — state inspector" at v0.1.0 (see VERSION.md and MOAT.md). Pre-v0.1 versions (0.0.1 through 0.0.10) shipped under the Agent Helm name and are preserved in `_old` doc snapshots.

## v0.1.0 — Released foundation
*The whole 0.0.x file-browsing-and-editing arc consolidated under the new name and direction.*

- [x] SSH connect (key-based, ed25519/RSA) and local file browsing (`FileManager`).
- [x] Per-host workspace paths.
- [x] Auto-connect on host selection; sleep/wake reconnect via `NSWorkspace` + `NWPathMonitor`.
- [x] Markdown rendering (MarkdownUI), JSON Graph + Pretty + Source, XML pretty-print, image/PDF preview.
- [x] Line-numbered source editor with regex syntax highlighting (10 languages).
- [x] Save / Discard / Cmd+S, dirty indicator.
- [x] Single-click selects, double-click navigates (Finder-style).

## v0.2.0 — SQLite inspector with agent-schema awareness *(next)*
The headline feature for the new direction. Mac-native, opinionated about known agent layouts.

- [ ] Recognize `.db`, `.sqlite`, `.sqlite3`, `.db3` as a new file kind.
- [ ] Open via [GRDB.swift](https://github.com/groue/GRDB.swift) in read-only mode.
  - Local: open the file directly.
  - Remote: SFTP-download to `~/Library/Caches/Rookery/`, open read-only, refetch on user-triggered refresh.
- [ ] **Tables / Schema / Query** modes:
  - **Tables**: sidebar of table names → paginated row view with column headers and type-aware cell rendering. JSON-in-a-cell auto-pretty-prints inline. BLOBs surface as size + first bytes.
  - **Schema**: full `CREATE TABLE` SQL + foreign keys + indexes + triggers for the selected table.
  - **Query**: read-only SQL editor (line-numbered, syntax-highlighted) → results pane. Refuses anything that's not SELECT/PRAGMA/EXPLAIN.
- [ ] **Agent-schema registry** — known SQLite layouts get first-class treatment:
  - Claude Code session DB (sessions / messages / memory tables) — display in chronological order with role-colored rows.
  - Aider history layouts.
  - OpenCode stores (when documented).
  - Generic vector-index tables (e.g., `embeddings(id, vector, metadata)`) — collapse vector blobs.
- [ ] Add `Models/AgentSchemas/` with one spec per known agent.

## v0.3.0 — JSONL transcript viewer
Companion to the SQLite inspector for the agents that store sessions as JSONL on disk.

- [ ] Recognize `.jsonl` as a new file kind.
- [ ] One message per row, expand inline to see content / tool calls / tool results.
- [ ] Role-colored rows (user / assistant / system / tool).
- [ ] Search within transcript.
- [ ] Tail mode for live-growing files.
- [ ] Common Claude Code session-transcript layouts known by default.

## v0.4.0 — Polish for the inspect-and-tweak loop
- [ ] Lock-for-Editing UI with multi-signal conflict detection (mtime + size + SHA-256 + git status when applicable). Becomes worth the complexity once SQLite + transcript live alongside live agent writes.
- [ ] Keychain integration for SSH passphrases (encrypted private keys).
- [ ] Onboarding: when a new host is added, sniff well-known paths (`~/.claude`, `~/.config/aider`, etc.) and offer to add them as workspaces.
- [ ] App Sandbox + security-scoped bookmarks for SSH key files (sandbox is OFF in pre-release builds).

## v0.5.0 — Real-time updates
- [ ] SFTP polling watcher with debounce — file tree updates when contents change on the remote.
- [ ] inotify-over-SSH bridge — sub-second refresh on remote.
- [ ] Live tail for SQLite (poll + incremental fetch on WAL changes).

## v1.0 — Polished release
- [ ] Signed and notarized DMG via GitHub Releases.
- [ ] Documentation site (GitHub Pages).
- [ ] Marketing page with the "read what your agents wrote" framing.

## Stretch / post-v1
- Postgres / MySQL DB browser (currently only SQLite is in scope).
- Diff view across two snapshots of an agent's state.
- Cross-host search ("find this string anywhere across all my agent state").
- Native iPad client for read-only inspection on the couch.

## Explicitly NOT on the roadmap

These were on the v0.x roadmap under the "Agent Helm — control plane" framing and have been removed under the Rookery direction:

- ~~Skill installer / uninstaller~~ — agent ecosystem isn't standardized; this is a moving target. ClawTab covers part of it for Claude.
- ~~Agent process supervisor (start/stop/tail)~~ — ClawTab and Claude Code Desktop own this.
- ~~Cron management~~ — Claude Code has scheduled tasks; ClawTab has cron.
- ~~"Control plane" framing in general~~ — too crowded, wrong posture.

If any of these come back, it'll be under a clear shift in market conditions, documented in MOAT.md.
