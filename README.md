# Agent Helm

> The Mac-native control plane for AI coding agents running on your own Linux servers.

Agent Helm connects to one or more Linux hosts over SSH and gives you structured editors for the things you actually need to manage when running Claude Code, OpenClaude, Aider, or similar agents on a remote box: the markdown files (skills, system prompts, notes), the agent's local SQLite databases, the cron schedules, and the agent processes themselves. One pane of glass, no terminal-juggling.

**Status:** v0.0.9. SSH + local browsing, **per-host workspaces**, auto-connect, **sleep/wake reconnect**. Markdown/MarkdownUI render. **JSON: Graph (collapsible + edit-in-place) / Pretty / Source**. XML pretty-print. Image + PDF preview. Line-numbered source editor with **syntax highlighting** for 10 languages. Save / Discard / dirty indicator, Cmd+S. SQLite browser and lock-for-editing are next. See [ROADMAP.md](docs/ROADMAP.md).

## Why

Today the dominant pattern for "Claude Code on a VPS" is `Termius + tmux + ssh + sqlite3 CLI + manually editing crontab`. That's four to five tools, none of which know an AI agent exists. Agent Helm collapses the operator workflow into one Mac-native app.

See [docs/MOAT.md](docs/MOAT.md) for the competitive landscape.

## Install

_(Pre-release. Build from source.)_

```bash
git clone https://github.com/dhravesh07/agent-helm.git
cd agent-helm/src
brew install xcodegen     # one-time
make bootstrap            # generates AgentHelm.xcodeproj from project.yml
make build
```

## Run

```bash
cd agent-helm/src
make run                  # builds and launches AgentHelm.app
```

Or open `AgentHelm.xcodeproj` in Xcode and hit ⌘R.

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
