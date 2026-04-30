# Agent Helm — Version

**Current:** `0.0.3` (pre-release walking skeleton — SSH connect + SFTP browse + markdown view)

## Changelog

### 0.0.3 — 2026-04-30
- **First functional slice.** Three of six v0.1 features land:
  - SSH connect to a single host with key-based auth (OpenSSH ed25519 and RSA, unencrypted keys for now). Powered by [Citadel 0.12.1](https://github.com/orlandos-nl/Citadel).
  - SFTP file tree browsing rooted at a configurable path; navigates into subdirs and back up. `~` resolves to remote `$HOME` after connect.
  - Markdown viewer using `AttributedString(markdown:)`; renders selected `.md` files inline. Non-markdown text files render as monospaced.
- App architecture:
  - `HostStore` (UserDefaults persistence, `@Observable`).
  - `SessionState` per host, holds connection status + remote listing + selected file.
  - `SSHService` actor — Citadel wrapper for connect / listDirectory / readTextFile / disconnect.
  - SwiftUI three-pane: hosts sidebar / file browser / viewer.
- Add Host UI with `NSOpenPanel` for picking the SSH private key file.
- App Sandbox **temporarily disabled** for the unsigned dev build so the app can read `~/.ssh/*` directly. See POLICY.md "Threat model" — sandbox + security-scoped bookmarks return in v1.0 with signing.
- Edit/save flow, save-conflict UX, and SQLite browser deferred to v0.0.4.

### 0.0.2 — 2026-04-30
- Add Xcode project generated from `src/project.yml` via xcodegen.
- Add `AgentHelm.entitlements` (App Sandbox, network client, user-selected files, downloads read-only).
- Add `Makefile` with `bootstrap`, `project`, `build`, `test`, `run`, `clean` targets.
- Build and test both pass via `xcodebuild`.
- `Package.swift` retained for fast CLI iteration; `AgentHelm.xcodeproj` gitignored (regenerated via `make bootstrap`).

### 0.0.1 — 2026-04-30
- Initial scaffold.
- Repository created, doc set populated, MIT license, SwiftPM skeleton.
- No functional code yet.

---

## Versioning policy

- SemVer (`MAJOR.MINOR.PATCH`).
- Pre-1.0: minor bumps for new features, patch for fixes.
- Post-1.0: standard SemVer (major = breaking).
- Tag every release in git: `git tag -a vX.Y.Z -m "..."`.
- Update the changelog above with every release; entries are append-only at the top.
- Run `../scripts/rotate-doc.sh docs/VERSION.md` before each release to preserve the prior changelog state.
