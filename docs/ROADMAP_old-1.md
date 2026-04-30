# Agent Helm — Roadmap

Versions follow SemVer. The big-picture order is fixed; specifics inside each milestone may shuffle as we learn.

## v0.1 — Walking skeleton (target: 2026-Q2)
The minimum that's useful to one person on one server.

- [ ] SSH connect to a single host with key-based auth (Keychain-stored passphrase).
- [ ] Browse remote filesystem from a configured root.
- [ ] Open and view `.md` files with rendered markdown.
- [ ] Edit `.md` files with save-back over SFTP. No live update yet — a manual refresh.
- [ ] Local SQLite DB browser: download to a tmp dir, open read-only, show schema + table viewer.
- [ ] App skeleton: SwiftUI three-pane (sidebar / file tree / content), Xcode project, signed local build.

**Definition of done:** I can edit a `CLAUDE.md` on my Linux box from my Mac in under 5 seconds and confirm the change took effect.

## v0.2 — Live updates + cron
- [ ] SFTP polling watcher with debounce — file tree updates when contents change on the remote.
- [ ] Conflict detection on save (mtime check + diff prompt).
- [ ] Cron tab: list, edit, validate, save the user's crontab.
- [ ] One-shot trigger for a cron entry (run-now).

## v0.3 — Skill installer + agent spawn
- [ ] Skill browser: list installed skills under `~/.claude/skills/` (and configurable extra paths).
- [ ] Install skill from a local `.zip` or directory: SFTP push + place.
- [ ] Spawn agent: configurable spawn command per host profile (default: `tmux new-session -d -s helm 'claude'`); attach output stream.

## v0.4 — Multi-host + history
- [ ] Manage multiple hosts; quick switcher.
- [ ] Cron run history viewer (parses configured log files; defaults to mail spool).
- [ ] Per-host dashboard: last spawn, last skill installed, recent file edits.

## v0.5 — Real-time push
- [ ] inotify-over-SSH bridge: a small helper script the app installs on first connect, that streams filesystem events back over the SSH channel.
- [ ] Sub-second refresh on file tree.

## v1.0 — Polished release
- [ ] Signed and notarized DMG via GitHub Releases.
- [ ] Onboarding flow: import existing SSH config, detect installed agents.
- [ ] Documentation site (GitHub Pages).
- [ ] App Store submission decision.

## Stretch / post-v1
- Postgres / MySQL DB browser (currently only SQLite is in scope).
- Plugin marketplace integration (only after the agent ecosystem standardizes a registry).
- Mobile companion (iOS) for read-only monitoring.
- Cross-platform client (Tauri rewrite) — only if cross-platform demand is real.
