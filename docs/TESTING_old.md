# Agent Helm — Testing

## Strategy

Three layers, in order of cost and confidence:

1. **Unit tests** — pure logic (cron parser, markdown diff, SFTP path resolution, DB-to-Swift mapping). Fast, deterministic, run on every commit.
2. **Integration tests** — exercise SSH, SFTP, SQLite, cron commands against a Dockerized Linux fixture (`tests/fixtures/sshd-claude/`). Run on PRs and pre-release.
3. **UI smoke tests** — drive the SwiftUI views via [ViewInspector](https://github.com/nalexn/ViewInspector). Cover golden-path flows. Run pre-release.

End-to-end UI testing through XCUITest is **not** prioritized for v0–v1 — too brittle for the velocity we want. Add it in v1+.

## Tools

- **XCTest** — built-in, runs everything.
- **ViewInspector** — SwiftUI introspection in tests.
- **Docker** — spins up an `ubuntu:24.04` container with `openssh-server`, a fake `~/.claude/` tree, a sample SQLite DB, and a seeded crontab. The container is the integration fixture.
- **swift-test-coverage** — coverage report; target ≥70% on non-UI modules.

## Running tests

```bash
# Unit + view inspection
cd agent-helm/src
swift test

# Or in Xcode
xed Package.swift     # opens the package
# Cmd-U to run tests
```

**Note:** if your `swift` resolves to Apple's Command Line Tools rather than Xcode, `swift test` will fail with `no such module 'XCTest'`. Use the Xcode toolchain explicitly:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

Or set Xcode as the active developer dir once: `sudo xcode-select -s /Applications/Xcode.app`.

For integration tests:

```bash
docker compose -f tests/fixtures/sshd-claude/docker-compose.yml up -d
swift test --filter IntegrationTests
docker compose -f tests/fixtures/sshd-claude/docker-compose.yml down
```

## Coverage targets

| Module | Target | Notes |
|---|---|---|
| SSH/SFTP wrapper | ≥80% | Core trust surface. Edge cases matter. |
| Cron parser/serializer | 100% | Pure functions, no excuse not to. |
| SQLite reader | ≥80% | Read-only, but malformed DBs are real. |
| Markdown diff/conflict | ≥80% | Save-conflict UX hinges on this. |
| SwiftUI views | ≥40% | Smoke only; visual regressions caught manually. |

## Fixture: `tests/fixtures/sshd-claude/`

Provides a reproducible Linux side. Contents:

- `Dockerfile` — Ubuntu + openssh-server + crond + sqlite3.
- `seed/` — sample `.claude/skills/`, sample `~/notes/agent.md`, sample `agent.sqlite`.
- `crontab.seed` — a few entries to test parsing.
- `docker-compose.yml` — exposes port 2222.

The fixture is checked in. Tests connect to `127.0.0.1:2222` with a fixed test key checked in to `tests/fixtures/sshd-claude/test_id_ed25519`.

## CI

GitHub Actions workflow (added in v0.2):
- `macos-latest` runner, Swift 5.9.
- `swift build` and `swift test` for unit/view tests on every push.
- Integration job runs on PR only (Docker boot is slow).

## Manual test checklist (pre-release)

Before tagging any release, run through:

1. Connect to a fresh server via password and via key.
2. Browse the file tree, open a `.md`, edit, save, verify on the server.
3. Trigger a save conflict (edit on server while edit pane is open) — confirm prompt appears.
4. Open a SQLite file >100 MB — verify it doesn't block the UI.
5. Add, edit, delete a cron entry — verify with `crontab -l` on the server.
6. Install a skill from a local zip — verify it appears under `~/.claude/skills/`.
7. Spawn an agent — verify the tmux session is created and output streams.
8. Disconnect the server (simulate network drop) — verify the app degrades gracefully.

Update this checklist whenever a feature ships.
