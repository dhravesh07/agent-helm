# Rookery — MOAT

*Last researched: 2026-04-30 (after the Anthropic SSH + scheduled-tasks shifts and the discovery of the AgentHelm name collision). Re-run before any major release; rotate this file per `CLAUDE.md`.*

## Positioning in one sentence
Rookery is the only **Mac-native, agent-aware state inspector** for AI coding agents — read-focused, local-first, cross-vendor (Claude Code, Aider, OpenCode, OpenClaude). It does **not** chat with the agent, run the agent, schedule the agent, or replace the agent's terminal. It reads the markdown / JSON / SQLite / transcripts the agent leaves behind.

## What changed since the April 1 research

The "AI agent control plane" category got crowded fast. Three shifts that informed Rookery's pivot from "control plane" framing:

1. **Anthropic shipped native SSH for Claude Code** (Feb 15, 2026) — the desktop app now connects directly to remote Linux servers. The "I want my Mac to drive Claude Code on a VPS" pain we were addressing is partially solved by Anthropic for Claude users. ([Anthropic docs](https://code.claude.com/docs/en/remote-control), [setup guide](https://medium.com/@0xmega/claude-code-on-a-vps-the-complete-setup-security-tmux-mobile-access-2d214f5a0b3b)).
2. **Anthropic shipped Scheduled Tasks** (Q1 2026) — `/loop`, Desktop scheduled tasks, cloud Routines. "Cron management for AI agents" is now a Claude Code primitive, not user-installed cron. ([Q1 2026 roundup](https://www.mindstudio.ai/blog/claude-code-q1-2026-update-roundup-2)).
3. **A direct competitor we missed: [ClawTab](https://clawtab.cc)** — Mac-native Tauri app, manages Claude Code/Codex/OpenCode locally, already has cron + Keychain secrets. MIT core, $4.99/mo paid relay. **Local-only, no SSH** — but probably 1–2 sprints from adding it.
4. **A name collision on the previous brand: [agenthelm.online](https://agenthelm.online)** (updated March 26, 2026) — Telegram-based remote control of agents; uses our former name. Drove the rename to Rookery.

## Direct competitors (state-inspection axis)

| Product | What it does | What it doesn't |
|---|---|---|
| [siteboon/claudecodeui (CloudCLI)](https://github.com/siteboon/claudecodeui) — 8.2k+ stars, monthly releases, [cloudcli.ai](https://cloudcli.ai) | Self-hosted **web** UI for Claude Code: chat surface, file tree, embedded shell, plugin tabs | Web app, not a Mac client. Focused on the *session/chat* surface; doesn't editorialize SQLite memory or JSONL transcripts. |
| [ClawTab](https://clawtab.cc) — MIT + paid relay tier ($4.99/mo) | Mac-native (Tauri+React) **agent runner / supervisor**: tmux session manager, cron, Keychain secrets, multi-vendor (Claude/Codex/OpenCode) | Local-only currently. Focused on running and steering agents; no DB inspection or structured transcript viewer. |
| [getAsterisk/claudia](https://github.com/getAsterisk/claudia) (Y Combinator) | Mac-native Tauri **agent management** for Claude Code: custom agents, sandboxing, usage analytics | Local-only. Issue [#163](https://github.com/getAsterisk/claudia/issues/163) "SSH support" open but not shipped. Doesn't expose agent state files structurally. |
| [Anthropic Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) | Drive a local Claude Code session from claude.ai or the Claude mobile app | Targets the **opposite topology**: phone/web → your local desktop. And only Claude Code. |
| Anthropic Claude Code SSH (Feb 2026) | Run Claude Code on a remote Linux server from the Mac desktop | Single-vendor (Claude Code). Doesn't expose agent state structurally; you SSH then poke around in the terminal. ([Known macOS bug flooding sessions](https://github.com/anthropics/claude-code/issues/48530)). |
| [Marc Nuri's AI Coding Agent Dashboard](https://blog.marcnuri.com/ai-coding-agent-dashboard) | Web dashboard for live agent overview + embedded terminal | Observability surface only — explicitly not for file editing, DB browsing, or structured state. |
| [Jam SQL Studio](https://jamsql.com/alternatives/best-sql-client-mac/) | Mac-native SQL IDE with built-in MCP/Claude Desktop support | Generic DB tool with AI; not agent-state-aware (no Claude Code session-DB schema, no Aider history layout). |

**No one is shipping agent-aware DB / transcript inspection.** That's the gap.

## Adjacent products users glue together today

For the inspection workflow, the dominant DIY stack is **[TablePlus](https://tableplus.com) or [Beekeeper Studio](https://www.beekeeperstudio.io) + a text editor + grep**. None of these know what a Claude Code session DB row means.

- **Mac DB browsers**: TablePlus, Beekeeper Studio — connect to remote SQLite via SSH, but generic — no agent-schema awareness.
- **Text editors with remote**: VS Code Remote-SSH, Cursor, Zed — strong for editing files; weak for DBs and transcripts.
- **Generic SSH GUIs**: Termius, Tabby — transport, no semantics.
- **Transcript viewers**: nothing Mac-native and dedicated. Users `cat | jq` JSONL transcripts in the terminal.

## The moat

What's defensible:

1. **Agent-schema awareness.** The SQLite tables Claude Code writes (sessions, messages, memory), the JSONL layouts Aider produces, OpenCode's state — Rookery can ship first-class views for each. Generic DB tools won't invest in vendor-specific schemas.
2. **Read-focused, not write-focused.** Every other tool wants to write to the agent (chat, prompt, run). Rookery's job is to **read**: see what the agent did, what it remembered, what it stored. Different posture, different UX.
3. **Cross-vendor by default.** Anthropic's SSH only helps Claude Code users. ClawTab supports a few. Rookery aims for any agent that writes to disk — Claude, Aider, OpenCode, OpenClaude, Continue, Cline, Codex.
4. **Mac-native + local-first.** Web UIs (CloudCLI) lose Mac integration. Local Tauri apps (ClawTab, Claudia) lose true Mac feel. Native SwiftUI is the right shape for an inspector that lives next to your editor.

## Risk factors

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Anthropic ships a session-DB browser inside Claude Code itself.** | Medium-low. Plausible, but Anthropic's Claude Code roadmap is heavily about agent capabilities, not operator surfaces. | Cross-vendor positioning. If Anthropic ships it for Claude Code, we're still the only thing for Aider/OpenCode users. |
| **ClawTab adds DB inspection.** | Medium. They're shipping fast and would benefit from it. | Be first; their Tauri stack makes a polished SQL pane harder than ours; lean on agent-schema awareness as a moat. |
| **TablePlus / Beekeeper add agent-schema templates.** | Low. They're focused on general DBs. | Schema templates are a marketing pitch we can do better. |
| **The agent ecosystem standardizes on a common state format** (e.g., MCP-defined storage). | Medium-long-term. Would erode the "vendor-specific schemas" advantage but expand the addressable market. | Adapt to the standard when it lands; in the meantime, schema-per-vendor is the work. |

## Demand signals

- "Where does Claude Code store my session?" / "How do I see what Aider remembered?" type questions on r/ClaudeAI, r/LocalLLaMA, GitHub issues — recurring.
- Articles about [SQLite as agent memory](https://www.welcomedeveloper.com/posts/ai-agent-memory-sqlite/), [AgentFS](https://turso.tech/blog/agentfs-fuse), [SQLite as the best DB for AI agents](https://dev.to/nathanhamlett/sqlite-is-the-best-database-for-ai-agents-and-youre-overcomplicating-it-1a5g) — the substrate is increasingly SQLite, increasingly worth inspecting.
- ClawTab's traction validates "Mac-native Tauri app to manage Claude/Codex/OpenCode" as a real category — Rookery's read-focused niche is adjacent, complementary.

## Re-research checklist (next pass)

- [ ] Has ClawTab added a SQLite/state-inspection view?
- [ ] Has Anthropic shipped any kind of session-DB browser inside Claude Code?
- [ ] Search GitHub for new "agent state inspector" / "claude-code-db" repos with traction.
- [ ] Pull 5+ dated quotes from r/ClaudeAI of users wanting to inspect their session DBs.
- [ ] Check whether MCP / agent-state standardization has produced a common format.
