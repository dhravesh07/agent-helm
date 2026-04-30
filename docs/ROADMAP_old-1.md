# Agent Helm — Roadmap

Versions follow SemVer. The big-picture order is fixed; specifics inside each milestone may shuffle as we learn.

## v0.1 — Walking skeleton (target: 2026-Q2)
The minimum that's useful to one person on one server.

- [x] SSH connect to a single host with key-based auth (Keychain-stored passphrase). *(unencrypted keys done in 0.0.3; Keychain integration with 0.0.6.)*
- [x] Browse remote filesystem from a configured root.
- [x] Open and view `.md` files with rendered markdown.
- [x] Local-Mac connection kind (added 0.0.4).
- [x] Auto-connect on host selection (added 0.0.5).
- [ ] **Workspace paths** abstraction (replaces single rootPath; per-host list of named paths) — **0.0.5**.
- [ ] Edit `.md` files with **Lock for Editing** model and multi-signal conflict detection (mtime + size + SHA-256 + optional git status) — **0.0.6**. See SCOPE.md "Editing model".
- [ ] Local SQLite DB browser: download to a tmp dir, open read-only, show schema + table viewer — **0.0.7**.
- [x] App skeleton: SwiftUI three-pane (sidebar / file tree / content), Xcode project. Signed build deferred to v1.0.

**Definition of done:** I can edit a `CLAUDE.md` on my Linux box from my Mac in under 5 seconds and confirm the change took effect.

## v0.2 — Connection resilience + cron
- [ ] **Connection lifecycle hardening:** subscribe to `NSWorkspace.didWakeNotification` / `willSleepNotification` and `NWPathMonitor`; mark sessions as `.reconnecting` on wake; auto-reconnect with exponential backoff; never let the UI lie about being connected after a sleep cycle. (Today, after a sleep/wake the UI still says "connected" but the next operation will hang — this is the v0.2 P0 fix.)
- [ ] SFTP polling watcher with debounce — file tree updates when contents change on the remote.
- [ ] Lock-for-Editing UI: the explicit lock button + integrity baseline + 3-way diff prompt on save conflict.
- [ ] Cron tab: list, edit, validate, save the user's crontab.
- [ ] One-shot trigger for a cron entry (run-now).

## v0.3 — Skill / agent lifecycle (full CRUD)
- [ ] **Supervisor profiles**: per-host configurable supervisor (tmux / screen / systemd-run / nohup / `&`). Spawn, attach, stop, and tail all go through the chosen profile — no tmux assumption.
- [ ] Skill browser: list installed skills under user-configured workspace paths.
- [ ] Install skill: SFTP-push a directory or zip into the chosen workspace path.
- [ ] **Uninstall skill:** remove its directory + any registered metadata file.
- [ ] Spawn agent via the host's supervisor profile.
- [ ] **Stop a running agent** (SIGTERM with grace period; configurable per supervisor).
- [ ] Tail / attach to the running agent's output via the supervisor profile.

## v0.4 — Multi-host, history, resource pruning
- [ ] Manage multiple hosts; quick switcher.
- [ ] Cron run history viewer (parses configured log files; defaults to mail spool).
- [ ] Per-host dashboard: last spawn, last skill installed, recent file edits.
- [ ] **Resource pruning UI:** per-host disk-use summary across configured workspace paths; one-click prune for old transcripts, vector indices, SQLite WAL files. Sized-and-aged previews before deletion; never deletes silently.

## v0.5 — Real-time push
- [ ] inotify-over-SSH bridge: a small helper script the app installs on first connect, that streams filesystem events back over the SSH channel.
- [ ] Sub-second refresh on file tree.

## v1.0 — Polished release
- [ ] Signed and notarized DMG via GitHub Releases.
- [ ] App Sandbox + security-scoped bookmarks for SSH key files (sandbox is OFF in pre-release builds).
- [ ] Onboarding flow: import existing SSH config; offer **discovery presets** to populate workspace paths from common Claude / Aider / OpenCode locations (the user accepts or edits).
- [ ] Documentation site (GitHub Pages).
- [ ] App Store submission decision.

## Stretch / post-v1
- Postgres / MySQL DB browser (currently only SQLite is in scope).
- launchd integration on macOS local hosts (cron-equivalent).
- Plugin marketplace integration (only after the agent ecosystem standardizes a registry).
- Mobile companion (iOS) for read-only monitoring.
- Cross-platform client (Tauri rewrite) — only if cross-platform demand is real.
