# Rookery

> Read what your AI agents wrote.

**Rookery** is a Mac-native inspector for the state your AI coding agents leave behind — the markdown configs, JSON sessions, SQLite memory stores, and JSONL transcripts that pile up in `~/.claude`, `~/.config/aider`, `.openclaude/`, and your project directories.

Local-first, with optional SSH for remote agents on Linux servers. Cross-vendor (Claude Code, Aider, OpenCode, OpenClaude, Continue, Cline). It's a **state inspector**, not a chat surface, not an SSH terminal, not an agent runner.

**Status:** v0.6.0 — feature-complete for the inspector + cron use cases.

- SSH + local browsing, per-host workspaces, auto-connect, sleep/wake reconnect, **auto-refresh polling toggle**.
- Markdown render (MarkdownUI), **JSON: Graph (collapsible + edit-in-place) / Pretty / Source**, XML pretty-print, image + PDF preview.
- **SQLite inspector** with Tables / Schema / Query modes, paginated grid, read-only SQL runner.
- **JSONL transcript viewer** with one-row-per-message, role-colored badges, expand-to-detail, live search.
- **Cron management** — Files / Cron surface picker; CRUD with Quick / Custom / Raw schedule picker; run-now; mail-spool run-history viewer.
- Line-numbered source editor with syntax highlighting for 11 languages.
- Save / Discard / Cmd+S, **save-conflict detection** (size + mtime + SHA-256 baseline; alert with Reload / Overwrite if the remote drifted).
- **Onboarding presets** for Claude Code / Aider / OpenCode / OpenClaude / Continue / Cline / Codex.

What's left for v1.0 (all gated on external prereqs): DMG signing + notarization (paid Apple Dev account), App Sandbox re-enable + security-scoped bookmarks (signed builds), Keychain for encrypted SSH key passphrases (real encrypted keys to test). See [ROADMAP.md](docs/ROADMAP.md).

> **Note:** Pre-v0.1 versions (0.0.1 through 0.0.10) shipped under the name "Agent Helm." The project was renamed to Rookery at v0.1.0 due to a name collision with [agenthelm.online](https://agenthelm.online) and a deliberate direction pivot from "control plane" to "state inspector." See [VERSION.md](docs/VERSION.md) for the full reasoning.

## Why

Today, peeking at agent state means juggling TablePlus + a text editor + grep + the agent's own TUI. None of those tools know what a Claude Code session-DB row means. Rookery is the Mac-native, agent-aware inspector that does.

See [docs/MOAT.md](docs/MOAT.md) for the competitive landscape and [docs/SCOPE.md](docs/SCOPE.md) for what's deliberately out of scope.

## Install

*(Pre-release. Build from source.)*

```bash
git clone https://github.com/dhravesh07/rookery.git
cd rookery/src
brew install xcodegen     # one-time
make bootstrap            # generates Rookery.xcodeproj from project.yml
make build
```

## Run

```bash
cd rookery/src
make run                  # builds and launches Rookery.app
```

Or open `Rookery.xcodeproj` in Xcode and hit ⌘R.

Signed and notarized DMGs ship with v1.0; current builds are unsigned local-dev only.

## Documentation

| Doc | What's in it |
|---|---|
| [POLICY.md](docs/POLICY.md) | License, contribution rules, security, privacy |
| [SCOPE.md](docs/SCOPE.md) | What's in / out of scope, tech stack, non-goals |
| [ROADMAP.md](docs/ROADMAP.md) | Milestones from v0.1 through v1.0 |
| [VERSION.md](docs/VERSION.md) | Current version + changelog |
| [USECASES.md](docs/USECASES.md) | Target users and primary workflows |
| [TESTING.md](docs/TESTING.md) | Test strategy and how to run tests |
| [MOAT.md](docs/MOAT.md) | Competitive analysis with citations |

## Contributing

PRs welcome. Read [POLICY.md](docs/POLICY.md) first; in short: open an issue, write tests, follow conventional commits, update docs (using the rotation policy in the workspace `CLAUDE.md`).

## License

[MIT](LICENSE).
