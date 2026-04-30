# Agent Helm — MOAT

*Last researched: 2026-04-30. Re-run before any major release; rotate this file per `CLAUDE.md`.*

## Positioning in one sentence
Agent Helm is the only **Mac-native, agent-aware, multi-host control plane** for self-hosted AI coding agents running on the user's own Linux servers — covering markdown editing, SQLite inspection, cron management, and skill/agent lifecycle in a single app.

## Direct competitors

| Product | Form factor | Overlap | Key gap vs Agent Helm |
|---|---|---|---|
| [siteboon/claudecodeui (CloudCLI)](https://github.com/siteboon/claudecodeui) — ~10k stars, v1.30.0 released 2026-04-21 | Self-hosted **web** UI for Claude Code sessions | File tree, chat, embedded shell, plugin tabs | Web app, not a Mac client. Focused on the *session/chat* surface, not on the operator surfaces (skills, SQLite, cron). |
| [getAsterisk/claudia](https://github.com/getAsterisk/claudia) — Y Combinator-backed Tauri app | **Local** Mac/Win/Linux desktop GUI | Custom agents, sandboxing, usage analytics | Local-first; assumes Claude Code is on the same machine. No SSH, no remote file/DB/cron. |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) — Ghostty-based Mac terminal | Mac-native terminal optimized for AI agents | Vertical tabs, notifications, supports `cmux ssh` | A terminal with affordances. Doesn't editorialize files/DBs/cron — it's still a terminal. |
| [vibetunnel](https://www.warp.dev/) (and similar Warp/Ghostty integrations) | Browser proxy of a Mac terminal | "Watch Claude Code from anywhere" | Pipes a terminal to a browser; doesn't expose structured editors. |
| [Marc Nuri's AI Coding Agent Dashboard](https://blog.marcnuri.com/ai-coding-agent-dashboard) | Web dashboard | Live overview across devices, embedded terminal, push notifications | Observability surface only — author explicitly says it's not for file editing, DB browsing, or cron. |
| [Anthropic Claude Code Remote Control](https://medium.com/@0xmega/claude-code-on-a-vps-the-complete-setup-security-tmux-mobile-access-2d214f5a0b3b) (released Feb 2026) | Mobile control of a local desktop session | Phone → your local Mac's running Claude Code | Targets the *opposite* topology: control your local box from a phone. Doesn't help if the agent runs on your Linux server. |

**None of these target the same problem shape:** Mac → SSH → Linux box → structured editing of agent state.

## Adjacent products that users glue together today

The dominant DIY stack on Reddit/Medium is **VPS + Tailscale + Termius + tmux** [[1]](https://medium.com/@0xmega/claude-code-on-a-vps-the-complete-setup-security-tmux-mobile-access-2d214f5a0b3b) [[2]](https://www.quantvps.com/blog/how-to-install-claude-code-on-vps). Pieces:

- **SSH GUIs**: [Termius](https://termius.com), [Royal TSX](https://www.royalapps.com/ts/mac), [Tabby](https://tabby.sh) — solve transport, not agent semantics.
- **Remote DB browsers**: [TablePlus](https://tableplus.com), [Beekeeper Studio](https://www.beekeeperstudio.io) — handle SQLite-over-SSH well; require separate setup.
- **Remote file editors**: [VS Code Remote-SSH](https://code.visualstudio.com/docs/remote/ssh), [Cursor](https://cursor.com), [Transmit](https://panic.com/transmit), [Mountain Duck](https://cyberduck.io) — solve markdown editing well, but not skill installs / agent spawn / cron.
- **Cron**: nothing Mac-native and modern. [Webmin](https://webmin.com) and [Cockpit](https://cockpit-project.org) cover it via web UI.

The current operator path requires **4–5 separate tools**, none of which know the agent exists. Agent Helm collapses that into one app that does.

## The moat

What's defensible:
1. **Agent-schema awareness.** Generic SSH/DB tools won't ship first-class views for `~/.claude/`, Claude Code session DBs, Aider history, OpenCode stores, etc. Agent Helm can.
2. **Operator surfaces, not chat surfaces.** Every existing GUI focuses on prompting/chatting with the agent. Agent Helm focuses on the boring operator state: skills installed, cron schedules, DB rows, md files. That's a different reader/buyer.
3. **Mac-native + remote.** Web UIs (CloudCLI) win mobile but lose Mac integration (menu bar, Keychain, Spotlight, notarization). Local apps (Claudia) lose remote. Agent Helm is the diagonal.
4. **Multi-host first-class.** Most adjacent tools assume one box.

## Risk factors — who could close the gap fastest

1. **siteboon/CloudCLI** (high) — already at 10k stars and shipping monthly; could add SQLite/cron tabs and a Tauri/Mac wrapper in 1–2 sprints. Mitigation: ship Mac-native quality (Keychain, native pickers, fast startup) they won't match in a Tauri wrapper.
2. **Cursor / VS Code Remote-SSH** (high) — already covers file editing remotely; an "Agent Console" extension is plausible. Mitigation: most Cursor users want to stay in the editor; Agent Helm targets the moments they're *not* editing.
3. **Termius** (medium) — strong remote infrastructure, could add a "Claude Code mode." Mitigation: their DNA is general SSH, not agent semantics.
4. **Anthropic** (low probability, high impact) — could extend Remote Control to address remote Linux topology. If they do, Agent Helm pivots to "open-source / cross-vendor" (Aider, OpenCode, OpenClaude) as the differentiation.
5. **Claudia (Asterisk, YC)** (medium) — well-funded, Mac-native, could add SSH. Mitigation: they're optimizing for local-Mac power users; remote-Linux is a different segment.

## Demand signals worth tracking

- Recurring "VPS + tmux + mobile" guides published monthly through 2025–2026 — sustained DIY pain [[Mar 2026 guide](https://medium.com/@0xmega/claude-code-on-a-vps-the-complete-setup-security-tmux-mobile-access-2d214f5a0b3b)] [[Feb 2026 iOS roundup](https://clauderc.com/blog/2026-02-28-best-ios-apps-for-remote-ai-coding-agents/)].
- Star velocity on `claudecodeui` (web UI, 10k stars) — evidence the *control plane* category is real, just under-served on Mac-native.
- Anthropic shipping Remote Control in Feb 2026 — validates the category but only addresses one topology (mobile → local Mac), leaving the Mac → remote Linux topology open.

## Re-research checklist (next pass)

- [ ] Check `claudecodeui` for SQLite/cron features (could close the gap).
- [ ] Search GitHub for new `claude-code-*` projects with >500 stars in the last 90 days.
- [ ] Check whether Claudia ships an SSH/remote mode.
- [ ] Pull 3–5 dated quotes from r/ClaudeAI for the demand-signals section.
