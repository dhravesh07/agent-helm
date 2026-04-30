# Agent Helm — Version

**Current:** `0.0.5` (auto-connect on selection + scope/roadmap corrections)

## Changelog

### 0.0.5 — 2026-04-30
- **Fix:** local hosts now auto-connect on selection. Previously the file browser showed "Not connected" until the user clicked the lightning-bolt toolbar button — actively confusing for local hosts where there's nothing to "connect" to. ContentView now triggers `session.connect()` from `.onChange(of: selectedHostId, initial: true)` whenever a session is in `.disconnected` state. Failed sessions are not auto-retried; the user retries explicitly so we don't loop on a bad config. (Triggered by user feedback that v0.0.4 "doesn't work" — it built and ran fine, but the UX was wrong.)
- **Docs corrections from architectural review** (rotated per CLAUDE.md):
  - `SCOPE.md` — five corrections:
    1. Removed tmux as the assumed default supervisor; introduced **supervisor profiles** (tmux / screen / systemd-run / nohup / `&`), user-selectable per host.
    2. Replaced single `rootPath` framing with **Workspace paths** abstraction (per-host ordered list of named paths). Discovery presets exist but no path is hardcoded — Aider's `.aider*` lives per-project, not in a home dir.
    3. Added **Editing model** section: files read-only by default, explicit Lock for Editing with mtime + size + SHA-256 + git-status integrity baseline; the multi-signal check is the real guarantee, not mtime alone.
    4. Added **Connection lifecycle (resilience)** section: `NSWorkspace` sleep/wake + `NWPathMonitor` requirements; never let the UI lie about connection state.
    5. Skill / agent lifecycle expanded with **Stop / Uninstall / Prune** — operator hygiene, not a v1.0 afterthought.
  - `ROADMAP.md` — restructured to reflect the corrections:
    - v0.1 expanded with workspace-paths and lock-for-editing as explicit gates.
    - v0.2 P0 is now connection-resilience hardening (sleep/wake) — currently broken in v0.0.4.
    - v0.3 calls out supervisor profiles explicitly; adds Stop and Uninstall.
    - v0.4 adds resource pruning UI (disk-use + one-click prune for transcripts / WAL).

### 0.0.4 — 2026-04-30
- Local-Mac connection kind alongside remote SSH.
- `RemoteFileService` protocol; `LocalFileService` actor backed by `FileManager`.
- `HostProfile.kind` field (defaults to `.remote` so v0.0.3 stored profiles decode cleanly).
- Form/list UI conditional on kind; folder picker for local roots.

### 0.0.3 — 2026-04-30
- First functional slice. SSH connect (OpenSSH ed25519 / RSA), SFTP file tree, markdown viewer.
- Architecture: `HostStore`, `SessionState`, `SSHService` actor, three-pane SwiftUI shell.
- Citadel 0.12.1 added as SwiftPM dependency.
- App Sandbox temporarily disabled (documented in POLICY.md).

### 0.0.2 — 2026-04-30
- Add Xcode project generated from `src/project.yml` via xcodegen.
- Add `AgentHelm.entitlements`, `Makefile` (bootstrap / build / test / run / clean).
- Build and test both pass via `xcodebuild`.

### 0.0.1 — 2026-04-30
- Initial scaffold.
- Repository created, doc set populated, MIT license, SwiftPM skeleton.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- Pre-1.0: minor bumps for new features, patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.
