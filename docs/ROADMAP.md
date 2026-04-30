# Rookery — Roadmap

Versions follow SemVer. Project pivoted from "Agent Helm — control plane" to "Rookery — state inspector" at v0.1.0 (see VERSION.md and MOAT.md). Pre-v0.1 versions (0.0.1 through 0.0.10) shipped under the Agent Helm name and are preserved in `_old` doc snapshots.

**As of v0.5.0, the inspector use case is feature-complete.** Remaining work is signing/notarization (needs paid Apple Developer account), Keychain (needs real encrypted SSH keys to validate), and stretch features.

## v0.1.0 — Released foundation
*The whole 0.0.x file-browsing-and-editing arc consolidated under the new name and direction.*

- [x] SSH connect (key-based, ed25519/RSA) and local file browsing (`FileManager`).
- [x] Per-host workspace paths.
- [x] Auto-connect on host selection; sleep/wake reconnect via `NSWorkspace` + `NWPathMonitor`.
- [x] Markdown rendering (MarkdownUI), JSON Graph + Pretty + Source, XML pretty-print, image/PDF preview.
- [x] Line-numbered source editor with regex syntax highlighting (10 languages).
- [x] Save / Discard / Cmd+S, dirty indicator.
- [x] Single-click selects, double-click navigates (Finder-style).

## v0.2.0 — SQLite inspector ✓ shipped
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

## v0.3.0 — JSONL transcript viewer ✓ shipped (in v0.5.0)
- [x] Recognize `.jsonl` and `.ndjson` as a new file kind.
- [x] One message per row, expand inline (chevron + double-click) to see content / tool calls / raw JSON.
- [x] Role-colored rows (user blue / assistant purple / system gray / tool orange / error red).
- [x] Search within transcript with live filtering and result count.
- [x] Common transcript shapes recognized: `role`+string content, `role`+array-of-blocks (Anthropic style), `type`+message.
- [ ] Tail mode for live-growing files — deferred to a later slice; auto-refresh covers directory-level updates today.

## v0.4.0 — Polish for the inspect-and-tweak loop ✓ partially shipped (in v0.5.0)
- [x] Save-conflict detection (multi-signal: size + mtime + SHA-256). Captures baseline at file-open; re-stats and re-hashes on save; raises an alert if the remote drifted (likely an agent rewrote it). Auto, not opt-in — user explicitly requested editing stay easy. (Lock-for-Editing as an opt-in upfront mode is deferred — drift detection on save covers the same need with less ceremony.)
- [x] Onboarding presets: "Add preset…" menu in the host form. 7 presets covering Claude Code / Aider / OpenCode / OpenClaude / Continue / Cline / Codex.
- [ ] Keychain integration for encrypted-key passphrases — needs real encrypted SSH keys to validate. Deferred until tester is available.
- [ ] App Sandbox + security-scoped bookmarks — needs signed builds (paid Apple Developer account). Deferred to v1.0.
- [ ] Git-aware diff: when the directory is a git repo, capture `git status` as a second integrity axis. Stretch.

## v0.5.0 — Real-time updates ✓ partially shipped
- [x] SFTP polling watcher: 5s polling toggle in the file browser, runs as a `Task` loop tied to view lifecycle, restarts on path change, cancels on disappear.
- [ ] inotify-over-SSH bridge for sub-second remote refresh — server-side helper script + streaming over SSH channel. Stretch; polling covers the universal case.
- [ ] Live tail for SQLite (poll WAL + incremental fetch). Stretch.

## v1.0 — Polished release
- [ ] Signed and notarized DMG via GitHub Releases.
- [ ] Documentation site (GitHub Pages).
- [ ] Marketing page with the "read what your agents wrote" framing.

## Stretch / post-v1
- Postgres / MySQL DB browser (currently only SQLite is in scope).
- Diff view across two snapshots of an agent's state.
- Cross-host search ("find this string anywhere across all my agent state").
- Native iPad client for read-only inspection on the couch.

## v0.6.0 — Cron CRUD + run history ✓ shipped (re-added by user request)

Was originally cut at the v0.1.0 pivot. User asked for it back; re-evaluated and concluded the niche is distinct from Anthropic Scheduled Tasks (Claude Code-internal) and ClawTab's cron (agent-process schedules). Rookery's cron manages the user's actual `crontab` for arbitrary scheduled commands across local Mac and remote Linux.

- [x] Files / Cron surface picker per host.
- [x] Read crontab via `crontab -l`, parse into preamble + entries with comments.
- [x] Three-mode schedule picker: Quick / Custom (5 fields) / Raw expression.
- [x] Friendly Quick presets: every minute / every N min / hourly / daily / weekly / monthly / at reboot.
- [x] Run-now button + captured output.
- [x] Save via `crontab <tmpfile>`. Validation runs first (plausibility + empty-command); strict validation defers to crontab itself.
- [x] History tab parses the user's mail spool for past runs.
- [ ] Custom log-file parsers for jobs that route output elsewhere — future.
- [ ] launchd integration on macOS — future stretch.

## Explicitly NOT on the roadmap

These were on the v0.x roadmap under the "Agent Helm — control plane" framing and have been removed under the Rookery direction:

- ~~Skill installer / uninstaller~~ — agent ecosystem isn't standardized; this is a moving target. ClawTab covers part of it for Claude.
- ~~Agent process supervisor (start/stop/tail)~~ — ClawTab and Claude Code Desktop own this.
- ~~"Control plane" framing in general~~ — too crowded, wrong posture.

If any of these come back, it'll be under a clear shift in market conditions, documented in MOAT.md.
