# Rookery — Version

**Current:** `0.6.1` (cron history — diagnostics + macOS unified-log fallback)

## Changelog

### 0.6.1 — 2026-04-30
**Fix: cron History tab is empty for the common macOS case.**

User reported creating an `echo hello` cron entry, installing it, and seeing nothing in History. Two reasons combined: (1) macOS rarely has a working MTA so cron drops output silently — `/var/mail/$USER` stays empty; (2) the empty-state was unhelpful about *why* it was empty.

Two fixes shipped:

1. **Diagnostic empty-state.** When `readRunHistory` returns no records, the History tab now shows a "What we checked" panel listing each probe and its result:
   - Mail spool path (`/var/mail/$USER`, `/var/spool/mail/$USER`) — present / missing / size in bytes
   - `MAILTO` setting in the user's crontab
   - cron / crond daemon presence (`pgrep -l`)
   - macOS unified-log fallback result (only on local hosts)
   Each diagnostic has a severity (info / warn / error) and an explanation. Plus a "Want to capture output anyway?" suggestion box explaining the `>> /tmp/cron-x.log 2>&1` workaround.
2. **macOS unified-log fallback for local hosts.** When the mail spool is empty AND the host is local, Rookery runs `log show --predicate 'process == "cron"' --info --style compact --last 1d` and parses each `cron: (user) CMD (...)` line into a `CronRunRecord` (timestamp + command, no output). The diagnostic banner notes "Using macOS unified log as fallback".

New files:
- `Models/CronDiagnostic.swift` — `CronDiagnostic` (severity + title + detail), `CronHistoryResult` (records + diagnostics).
- `CronHistoryParser.parseUnifiedLog` — extracts `CMD (...)` payloads from `log show` output.

Changes:
- `CronService.readRunHistory(hostKind:)` now returns `CronHistoryResult` and runs diagnostic probes.
- `CronState` adds `historyDiagnostics`.
- `SessionState.loadCronHistory` passes `profile.kind` so the service knows whether to try the macOS unified-log fallback.
- `CronView.CronHistoryPane` renders the empty-state with the diagnostics panel; when records exist, a collapsible diagnostics banner sits at the top.

Project version: 0.6.0 → 0.6.1; CURRENT_PROJECT_VERSION 60 → 61.

#### Why the unified-log fallback can't show output
`log show` only records that cron *fired the job* — it doesn't capture stdout/stderr. To get the actual output back into Rookery, the user has to redirect output (`>> /tmp/cron-x.log 2>&1`) and read the log file from the Files surface. A built-in "capture to file" toggle in the entry editor is on the roadmap as a v0.7 polish.

### 0.6.0 — 2026-04-30
**Cron CRUD + run history.** User decided to bring cron management back in scope after the v0.1.0 pivot had explicitly cut it. Re-evaluated: while Anthropic Scheduled Tasks and ClawTab cover their own niches, neither is a portable cron manager for arbitrary user-installed cron jobs across local Mac and remote Linux. Different scope, complementary.

#### Surface picker
The host pane now has a **Files / Cron** segmented picker in the toolbar. Switching is instant; both surfaces share the same connection. Cron data lazy-loads on first switch.

#### Cron entries (CRUD)
- New `Models/CronEntry.swift` — `CronEntry` (id, schedule, command, comment) + `CronSchedule` enum with `.standard(minute:hour:dom:month:dow:)`, `.shorthand(...)` for `@daily`/`@hourly`/etc., and `.raw(...)` fallback. Smart `summary` getter detects common patterns ("Every day at 09:30", "Every 5 minutes", "Every week on Monday at 14:00", etc.).
- New `Models/CronParser.swift` — parses `crontab -l` output into preamble (env vars + standalone comments) and entries. Round-trips unchanged: standalone comments + env vars are preserved on save.
- New `Services/CronService.swift` — façade over `RemoteFileService`. List, save (write to `/tmp/rookery-crontab-<uuid>` via SFTP, then `crontab <tmp>`, then cleanup), validate, run-now (`{ command ; } 2>&1`), and read mail spool.
- New `Models/CronState.swift` — `@Observable` per-session cron data: tab, preamble, entries, selection, status, dirty flag, validation problems.
- `SessionState` gains `cron: CronState` + methods: `loadCron`, `saveCron`, `runCronNow`, `loadCronHistory`, `addCronEntry`, `deleteCronEntry`, `updateCronEntry`.

#### Friendly schedule picker
- New `Views/CronEntryEditor.swift` with three modes:
  - **Quick**: predefined kinds — every minute / every N minutes (stepper) / every hour / every day (HH:MM picker) / every week (weekday + HH:MM) / every month (day + HH:MM) / at reboot. Hydrates from any parsed schedule that matches a known pattern.
  - **Custom (5 fields)**: minute / hour / day-of-month / month / day-of-week TextFields with inline hints and a live "Resulting expression" preview.
  - **Raw expression**: free-text TextField for power users; accepts shorthands and arbitrary cron syntax.
- Command + comment fields below the schedule picker. Multi-line command support.
- **Run now** button + result pane that captures combined stdout/stderr.

#### Cron view
- New `Views/CronView.swift`. Two-tab layout (**Entries** / **History**) controlled by `CronTab` enum.
- Entries tab: `HSplitView` with sidebar (validation banner + entries list with schedule summary + command monospaced + optional comment) and editor pane on the right. Add / Delete / Reload / Install crontab (⌘S) buttons.
- History tab: parses `/var/mail/$USER` (or `/var/spool/mail/$USER` fallback) via the new `CronHistoryParser`. Each cron run-with-output becomes a `CronRunRecord` (timestamp, command, output) — listed newest-first with `DisclosureGroup` to expand the full captured output.
- Save flow runs validation first (empty commands, plausibility check on each field, unknown shorthands); errors surface in the validation banner instead of going through to the server.

#### Plumbing
- New `runShellCommand(_:)` requirement on `RemoteFileService`. `LocalFileService` implements it via `Process` with `/bin/sh -c`; `SSHService` implements it via Citadel's `executeCommand`.
- ContentView dispatches the content pane based on `session.surface`. The detail pane is empty for cron (single-pane surface).
- Project version: 0.5.0 → 0.6.0; CURRENT_PROJECT_VERSION 50 → 60.

#### Known limitations
- macOS local: `crontab` works on macOS but `launchd` is the more idiomatic scheduler. Rookery uses `crontab` for both kinds for now; launchd integration (`launchctl list`, `~/Library/LaunchAgents/*.plist` editor) is a future stretch.
- History parsing depends on cron writing to the user's mail spool. If `MAILTO` is unset or mail isn't configured, the History tab will be empty — documented in the empty-state copy. Custom log-file parsers can be added later.
- Validation is loose at the field level. Strict server-side validation happens at install time when `crontab <file>` rejects the input; that error surfaces in the save-status label.

### 0.5.0 — 2026-04-30
**Three roadmap milestones in one ship**, covering the full v0.3 / v0.4 / v0.5 spans of the original ROADMAP. Rookery's read-and-tweak loop is now feature-complete for the inspector use case.

#### v0.3.0 features — JSONL transcript viewer
- New `Views/JSONLTranscriptView.swift`. Recognized by file extensions `.jsonl` and `.ndjson`.
- One message per row: line number → role badge (color-coded: user blue, assistant purple, system gray, tool orange, error red) → preview line.
- **Click chevron or double-click row** to expand. Expanded view shows full `Content`, any `Tool calls` (each pretty-printed as JSON in a chip), and a collapsible "Raw JSON" disclosure with the whole prettified line.
- **Search bar** at top; live-filters by content / role / raw JSON across all entries. Live result counter.
- Handles common transcript shapes: `role` + string `content`, `role` + array-of-blocks `content` (Anthropic-style with `text` blocks), `type` + `message`, raw arbitrary JSON objects (preview = key summary). Lines that don't parse as JSON show as raw text rather than disappearing.

#### v0.4.0 features — Onboarding presets + save-conflict detection
- New `Models/AgentPresets.swift` with curated workspace lists for **Claude Code, Aider, OpenCode, OpenClaude, Continue, Cline, Codex** (7 presets, 16 paths total).
- Host form gets an **"Add preset…" menu** next to "Add workspace". One click adds the preset's workspaces; duplicate paths are skipped; the placeholder "Root" workspace is replaced if untouched.
- New `Models/EditLock.swift` with `EditLockBaseline` (path + size + mtime + SHA-256 + lockedAt) and `SaveConflict` enum.
- `SessionState` captures a baseline at file-open time (size + mtime + SHA-256 of contents). On save, re-stats and re-hashes the remote; if the SHA differs from the baseline, the save is paused and `pendingConflict` populated.
- Conflict alert in `FileEditorView`: **Reload** (cancel local edits, refetch), **Overwrite** (force-save, clobber the agent's writes), or **Keep editing**. Crucial for the case where a running agent rewrites the file you've been editing.
- After a successful save, the baseline refreshes to the just-saved state so subsequent saves compare against it.
- Conflict detection is automatic, no upfront "Lock" button — the user requested editing stay easy. The check happens transparently on save.

#### v0.5.0 features — SFTP polling watcher
- File browser header gets an **auto-refresh toggle** (the wave-3-right SF Symbol). When on, polls `listDirectory` every 5 seconds in a `Task` loop tied to view lifecycle.
- Path change cancels and restarts the loop so refresh fires immediately for the new directory.
- View disappear cancels the loop. No leaked timers.
- True inotify-over-SSH (a server-side helper script that streams events) is still the longer-term path; polling is the universal fallback that works against any SFTP server with no remote install.

#### Other touches
- SQL added as the 11th syntax-highlighting language (used by SQLiteBrowserView's query editor).
- `clearFileBuffer` now resets the edit baseline and pending conflict.
- Project version: 0.2.0 → 0.5.0; CURRENT_PROJECT_VERSION 20 → 50.

#### What's still deferred (post-v1)
- True inotify-over-SSH (sub-second remote refresh).
- Live SQLite tail (poll WAL + incremental fetch).
- Sandbox re-enable + security-scoped bookmarks for SSH keys (needs signed builds).
- Keychain integration for encrypted-key passphrases (needs real encrypted keys to validate against).
- DMG signing + notarization (needs paid Apple Developer account).

### 0.2.0 — 2026-04-30
**SQLite inspector for agent state.** The flagship feature for the post-pivot direction.

- New `PreviewableFileKind.sqlite` for `.db`, `.sqlite`, `.sqlite3`, `.db3`. JSONL also recognized as `.jsonl` / `.ndjson` (viewer ships in v0.3.0).
- Three view modes for SQLite: **Tables / Schema / Query**. Picker auto-shows in the file editor header.
- New `Services/SQLiteService.swift` — actor wrapping [GRDB.swift 7.10](https://github.com/groue/GRDB.swift) with `Configuration.readonly = true`. Read-only at the connection level, AND the query runner refuses anything that isn't `SELECT` / `WITH` / `PRAGMA` / `EXPLAIN`.
- New `Models/SQLiteSchema.swift` — `SQLiteTable`, `SQLiteColumn`, `SQLiteRow`, `SQLiteResultSet` value types.
- New `Views/SQLiteBrowserView.swift`:
  - **Tables mode**: `HSplitView` with table sidebar (name + row count) and main pane showing table metadata + paginated data grid (50 rows per page) + page controls.
  - **Schema mode**: column list with primary-key indicator, type, NOT NULL / DEFAULT constraints; full `CREATE` statement below.
  - **Query mode**: line-numbered SQL editor (`LineNumberedTextEditor` with new SQL syntax-highlighting language spec) on top, results grid below in a `VSplitView`. ⌘↩ runs the query. Up to 1000 rows, truncation indicator if exceeded.
- `SessionState.openSQLite` handles file opening: local files open directly; remote files SFTP-download to `~/Library/Caches/Rookery/<host>-<hash>.db` and open from there. New `maxSQLiteSize = 200 MB` cap (separate from the 5 MB text-edit cap).
- `FileBufferState.sqlite(localPath: URL, size: UInt64)` new case; `FileEditorView` dispatches to `SQLiteBrowserView` for it.
- Added SQL to `SyntaxLanguages` (case-insensitive keyword matching for SELECT/FROM/WHERE/JOIN/etc.).
- `RookeryTests`: build still passes via `xcodebuild test`.

#### Known limitations (deferred)
- BLOBs surface as `<blob N bytes>` strings; full hex dump / image preview is a future tweak.
- Remote DB refresh is manual via the table refresh button — re-fetches the whole file. Live tail (poll + WAL) is v0.5.
- Agent-schema awareness (Claude Code session-DB layouts, Aider chat history, OpenCode stores) — registry skeleton is in place; specific schema templates land as we verify each agent's actual file layout against a real installation.

### 0.1.0 — 2026-04-30
**Project rename and direction pivot.** Was: "Agent Helm — Mac-native control plane for AI coding agents." Now: **"Rookery — Mac-native inspector for AI coding agent state."**

#### Why the rename
- The name "Agent Helm" was already in use by [agenthelm.online](https://agenthelm.online) (Telegram-based remote agent control, updated March 26, 2026). Same name + overlapping positioning + their SEO advantage = inevitable confusion. Rebrand was the right move.
- "Rookery" is a colony where birds nest — the mental image: where your AI agents leave their nests of records (transcripts, configs, DBs). Single word, distinctive, clear in the dev-tools / AI agent space.

#### Why the direction pivot
A step-back review of the market between April 1 and April 30 surfaced three shifts:

1. **Anthropic shipped native SSH for Claude Code** (Feb 15) — the "drive an agent on a remote VPS from my Mac" pain we were addressing is partially solved by Anthropic for Claude users.
2. **Anthropic shipped Scheduled Tasks** (Q1 2026) — `/loop`, Desktop scheduled tasks, cloud Routines. "Cron management for AI agents" is now a Claude Code primitive.
3. **[ClawTab](https://clawtab.cc)** — a direct competitor we missed (Mac-native Tauri, runs Claude/Codex/OpenCode locally, has cron + Keychain secrets, MIT + paid relay). Probably 1–2 sprints from adding SSH.

In that landscape, "control plane" framing is too crowded and we'd be racing well-funded competitors on their core feature. **Direction A — operator tool for agent state — is sharper, less crowded, and plays to native-Mac strengths.**

What we kept (already shipped under the Agent Helm name):
- SSH + local file browsing.
- Workspace paths per host.
- Markdown / JSON Graph / XML / image / PDF preview.
- Line-numbered source editor with syntax highlighting.
- Sleep/wake reconnect.
- Single-click select / double-click navigate.

What we explicitly dropped from scope (see ROADMAP.md):
- ~~Skill installer~~
- ~~Agent process supervisor (spawn / stop / tail)~~
- ~~Cron / scheduled-task management~~
- ~~"Control plane" framing~~

What we're adding next (the direction-A moat):
- **v0.2.0** — SQLite inspector with agent-schema awareness (Claude Code session DB, Aider history, OpenCode stores). The headline feature for the new direction.
- **v0.3.0** — JSONL transcript viewer.

#### Mechanical changes
- Repo renamed: `dhravesh07/agent-helm` → `dhravesh07/rookery`.
- Local dir: `macSoftware/agent-helm/` → `macSoftware/rookery/`.
- Swift module: `AgentHelm` → `Rookery`. Source dirs and entitlements file renamed.
- Bundle ID: `dev.dhravesh.AgentHelm` → `dev.dhravesh.Rookery`. Test bundle the same.
- Display name in `Info.plist`: "Agent Helm" → "Rookery".
- All current docs (POLICY, SCOPE, ROADMAP, USECASES, MOAT, TESTING, VERSION) rewritten for the new name and direction. Pre-rename versions preserved as `_old` rotations per the workspace's CLAUDE.md policy.
- `HostStore` `UserDefaults` key migrated from `AgentHelm.hosts.v1` to `Rookery.hosts.v1`. **Existing host profiles do not auto-migrate** — re-add the host on first launch (one-time, ~30 seconds).

#### Past changelog (Agent Helm era, kept for continuity)

The v0.0.x history, in brief:

- **0.0.10** — Single-click selects, double-click navigates (Finder-style).
- **0.0.9** — Workspaces, sleep/wake resilience, syntax highlighting, JSON graph collapsibility + edit-in-place.
- **0.0.8** — XML support, line numbers, JSON Graph view (initial).
- **0.0.7** — MarkdownUI, image preview, PDF preview, JSON pretty-print, per-file-kind dispatch.
- **0.0.6** — Read & edit any UTF-8 text file. Markdown Preview/Source toggle.
- **0.0.5** — Auto-connect on host selection. Architectural-review docs corrections.
- **0.0.4** — Local-Mac connection kind alongside remote SSH.
- **0.0.3** — First functional slice. SSH + SFTP file tree + markdown viewer.
- **0.0.2** — Xcode project via xcodegen, Makefile.
- **0.0.1** — Initial scaffold under the name "Agent Helm."

Full prior-version detail lives in `VERSION_old.md` and earlier rotations.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- v0.1.0 marks the rename + direction pivot; subsequent minor bumps for new features (v0.2 = SQLite, v0.3 = transcripts), patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.
