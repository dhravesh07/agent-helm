# Rookery — Use Cases

## Target users

**Primary:** developers running AI coding agents (Claude Code, OpenClaude, OpenCode, Aider, Continue, Cline) on their **own Mac**, who want a structured way to inspect what those agents have been writing — markdown configs, JSON sessions, SQLite memory, JSONL transcripts.

**Secondary:** the same developers, with the agent on a **remote Linux server** (VPS, home lab, workstation), inspecting from their Mac via SSH.

**Not the target:**
- People who only use a fully hosted agent (claude.ai web, Devin, Replit Agents) — there's no on-disk state to read.
- People who want to **prompt** the agent from a Mac UI — claude.ai/code, the Claude app, claudecodeui already cover that surface.
- People who want to **run / spawn / supervise** the agent — ClawTab and Anthropic Desktop are better tools for that.

## Primary use cases

### UC-1 — "What does Claude Code remember about this project?"
*Casey wants to see the session memory Claude Code has built up across yesterday's coding session. Today: dig into `~/.claude/projects/.../` and read JSONL transcripts in `cat | jq`. With Rookery: open the project workspace, see the session DB tables side-by-side with the transcript, click a message to see the tool call and response inline.*

### UC-2 — "Why did Aider rewrite this file last night?"
*Priya runs Aider as a daemon. The next morning she finds a file edited and wants to understand why. Today: `git diff` for the what, then nothing for the why (Aider's reasoning lives in `.aider.chat.history.md` per project). With Rookery: open the project workspace, scroll the chat history with proper rendering, find the prompt and reasoning that produced the edit.*

### UC-3 — "Tweak a CLAUDE.md skill in place"
*Marco has 12 skills in `~/.claude/skills/`. He wants to refine one quickly. Today: open VS Code, navigate to the file, edit, save. With Rookery: rookery, sidebar → Skills workspace → file → edit → ⌘S. One window. Designed for the inspect-and-tweak loop, not the multi-file IDE workflow.*

### UC-4 — "Inspect agent SQLite memory"
*Lin's agent stores rolling memory in SQLite. She wants to see if a particular fact was retained. Today: open TablePlus, configure a connection, find the right table, write a SELECT, decode JSON-in-a-cell. With Rookery (v0.2): open the .db file inline, see the table list in agent-schema-aware order (sessions / messages / memory before SQLite internals), expand a row to see the JSON payload pretty-printed.*

### UC-5 — "Browse a remote Claude Code session from my Mac"
*Daniel runs Claude Code on a $40 VPS. He wants to peek at what it's been doing without SSHing into a terminal. Today: `ssh box && cd ~/.claude && cat`. With Rookery: add a remote host with a workspace path at `~/.claude`, browse the session tree, open files, edit configs, save back over SFTP.*

### UC-6 — "Multiple agents, one inspector"
*Eli uses Claude Code on the laptop, Aider on a server, and OpenCode on a workstation. Each has its own state layout. With Rookery: three host profiles, switch between them, read each one's records in the same UI. Cross-vendor by design.*

## Anti-use-cases (explicit)

- **"I want to chat with my agent from a Mac UI."** → claude.ai, [claudecodeui](https://github.com/siteboon/claudecodeui), Claude Desktop. Rookery doesn't render a chat surface.
- **"I want to start / stop / supervise my agent."** → [ClawTab](https://clawtab.cc) or [claudia](https://github.com/getAsterisk/claudia). Rookery doesn't manage agent processes.
- **"I want to schedule the agent to run every hour."** → Claude Code's `/loop` and Desktop Scheduled Tasks; ClawTab's cron. Rookery doesn't manage schedules.
- **"I want a general SSH terminal."** → Termius, Tabby, iTerm2.
- **"I want a general SQL client."** → TablePlus, Beekeeper Studio. Rookery's DB browser is opinionated about agent schemas, not a full SQL workbench.

## Success signals

- A user can open Rookery and find what the agent has been writing within 60 seconds of first launch.
- A user can navigate from "vague unease about what the agent did" to "specific evidence" without leaving the app.
- A user uses Rookery alongside, not instead of, their primary editor — it's the inspector tab, not the workspace.
- The DB browser surfaces Claude Code's session-DB layout meaningfully on first open, without the user configuring schemas.
