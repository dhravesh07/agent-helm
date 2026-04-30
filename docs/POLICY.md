# Rookery — Policy

## License
MIT License. Full text in [LICENSE](../LICENSE).

## Contributing
Contributions welcome. To contribute:

1. Open an issue describing the change before starting non-trivial work.
2. Fork, branch, and open a PR against `main`.
3. PRs must include tests for any logic changes (see [TESTING.md](TESTING.md)).
4. PRs must update relevant docs in `docs/` using the rotation policy in the repo's `CLAUDE.md` (current keeps its name, prior version is rotated to `_old.md`).
5. Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.

## Code of Conduct
This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code-of-conduct/). Report violations privately to dhravesh@gmail.com.

## Security
**Reporting a vulnerability:** email dhravesh@gmail.com with subject `Rookery security`. Do **not** file a public issue. Expect an acknowledgment within 72 hours.

**Threat model:** Rookery holds SSH credentials and runs arbitrary commands on remote hosts. It is a sensitive client. Specifically:
- All connections are SSH (no plaintext protocols).
- The app does not phone home; no telemetry is sent anywhere.
- Remote command execution is logged locally and surfaced in the UI before it runs (no silent shell-outs).

**Status of credential storage and sandboxing (v0.0.3):**
- App Sandbox is **temporarily disabled** in pre-release builds so the app can read SSH key files (e.g., `~/.ssh/id_ed25519`) directly via `FileManager`. This is a development convenience and trades sandbox isolation for setup simplicity.
- Private key paths are stored in `UserDefaults` (plain JSON). Keys themselves are read from disk on demand, never persisted by the app.
- **macOS Keychain integration for any future passphrases lands in v0.0.4.** Sandbox + security-scoped bookmarks return in v1.0 alongside code signing and notarization. Until then, do not run pre-release builds on machines you don't fully control.

## Privacy
- Local-first. No data leaves the user's Mac except over SSH to user-configured servers.
- No analytics, no crash reporting service, no telemetry. Crashes go to the user's own `~/Library/Logs/`.
- The app never reads files outside the directories the user explicitly browses.

## Distribution
- Distributed as source from this repo.
- Once stable: signed and notarized DMG via GitHub Releases. App Store distribution is a stretch goal (see [ROADMAP.md](ROADMAP.md)).
