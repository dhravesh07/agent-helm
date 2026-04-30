# Rookery

> Read what your AI agents wrote.

**Rookery** is a Mac-native inspector for the state your AI coding agents leave behind — the markdown configs, JSON sessions, SQLite memory stores, and JSONL transcripts that pile up in `~/.claude`, `~/.config/aider`, `.openclaude/`, and your project directories.

Local-first, with optional SSH for remote agents on Linux servers. Cross-vendor (Claude Code, Aider, OpenCode, OpenClaude, Continue, Cline). It's a **state inspector**, not a chat surface, not an SSH terminal, not an agent runner.

**Status:** v0.1.0. SSH + local browsing, per-host workspaces, auto-connect, sleep/wake reconnect. Markdown / JSON Graph / XML / image / PDF preview. Line-numbered source editor with syntax highlighting for 10 languages. Save / Discard / Cmd+S. **SQLite inspector with agent-schema awareness lands in v0.2.0** (the headline feature for the new direction). See [ROADMAP.md](docs/ROADMAP.md).

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
