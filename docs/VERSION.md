# Rookery — Version

**Current:** `0.5.0` (JSONL transcripts + onboarding presets + save-conflict detection + auto-refresh)

## Changelog

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
