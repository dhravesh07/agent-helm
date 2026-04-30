# Agent Helm — Version

**Current:** `0.0.4` (pre-release — local + remote browsing)

## Changelog

### 0.0.4 — 2026-04-30
- **Local-Mac connection kind.** A host can now point at a folder on the current Mac (e.g., `~/.claude`, an `openclaude` directory, any project root). Same browser, same markdown viewer, no SSH.
- New `RemoteFileService` protocol abstracts the filesystem layer:
  - `SSHService` (existing) handles remote SFTP via Citadel.
  - `LocalFileService` (new actor) handles local browsing via `FileManager`.
  - `SessionState` picks the right backend based on `HostProfile.kind`.
- `HostProfile.kind` (`.local` / `.remote`) stored alongside the existing fields. v0.0.3 profiles decode cleanly — missing `kind` defaults to `.remote`.
- Add Host form gets a segmented kind picker; remote-only fields hide for local. Folder-picker button for local hosts.
- Sidebar shows a kind icon (`macbook` / `server.rack`) + a context-appropriate subtitle (folder path for local, `user@host:port` for remote).
- Connection toolbar relabels to "Open / Close" for local hosts, "Connect / Disconnect" for remote.

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
