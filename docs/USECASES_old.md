# Agent Helm — Use Cases

## Target users

**Primary:** developers running an AI coding agent (Claude Code, OpenClaude, OpenCode, Aider) on their own Linux server — VPS, home lab, workstation, or dedicated box — and using a Mac as their daily driver.

**Secondary:** AI/ML researchers running long-lived agent processes on a remote workstation and needing a low-friction way to inspect what the agent is doing without a full SSH session.

**Not the target:** people who only use Claude Desktop, Cursor, or a hosted product. They have nothing remote to manage.

## Primary use cases

### UC-1 — Live-edit a CLAUDE.md from the Mac
*Sam runs Claude Code on a $40/mo VPS. They want to tweak the project's `CLAUDE.md` to refine the agent's behavior. Today: SSH, vim, save, hope. With Agent Helm: open the file in a real editor, with preview, save in one click. Total time: 30 seconds vs. 3 minutes.*

### UC-2 — Inspect agent memory mid-run
*Priya is running a long-form coding task and wants to know what the agent has learned so far. The agent stores transcript and memory in a SQLite file. With Agent Helm: open the DB, browse the `memories` table, see exactly what's in there. No `sqlite3` CLI gymnastics.*

### UC-3 — Schedule a nightly skill run
*Marco wants his agent to refresh a research dataset every night at 2am. With Agent Helm: open the Cron tab, pick a schedule from the dropdown, paste the command, save. View tomorrow's run output the next morning.*

### UC-4 — Install a community skill
*Lin downloads a `pdf-extract.skill` from a community repo. With Agent Helm: drag-drop into the Skills pane on her server profile; the app SFTPs it to `~/.claude/skills/pdf-extract/` and confirms the install. The next agent run picks it up.*

### UC-5 — Spawn a one-off agent for a task
*Daniel wants to kick off a refactoring agent on the server without opening a terminal. With Agent Helm: hit "New Agent", paste the task into a prompt box, click run. The app spawns a `tmux` session, streams output back to the Mac.*

### UC-6 — Manage three servers at once
*Eli runs experiments across three boxes. With Agent Helm: a sidebar of host profiles, click to switch, see each box's recent file changes and cron history side-by-side.*

## Anti-use-cases (explicit)

- **"I want to run an agent on my Mac."** → Use Claude Code Desktop, Cursor, or `claude` in your local terminal. Agent Helm is a remote-only client.
- **"I want a general SSH terminal."** → Use Termius, Tabby, or iTerm2.
- **"I want to manage agents across a fleet of cloud-managed VMs."** → Agent Helm scales to ~10 hosts. For 100+, use proper cloud orchestration.
- **"I want a web dashboard."** → Agent Helm is a native Mac app, not a hosted UI. (LangSmith, AgentOps cover the hosted-dashboard space.)

## Success signals
- A user can connect, edit a remote `.md`, and see the change reflected in <60 seconds from app launch.
- A user has zero need to open a terminal for the canonical happy-path tasks above.
- A user can manage 3+ hosts without confusion about which one they're acting on.
