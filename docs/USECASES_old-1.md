# Rookery — Use Cases

## Target users

**Primary:** developers running an AI coding agent (Claude Code, OpenClaude, OpenCode, Aider) on their own Linux server — VPS, home lab, workstation, or dedicated box — and using a Mac as their daily driver.

**Also primary (v0.0.4+):** developers running the same agents directly on their Mac. Rookery in **Local** mode points at a folder (e.g., `~/.claude`) and surfaces the same operator views (md files, soon: SQLite, cron) without any SSH plumbing.

**Secondary:** AI/ML researchers running long-lived agent processes on a remote workstation and needing a low-friction way to inspect what the agent is doing without a full SSH session.

**Not the target:** people who only use a fully hosted product (Claude.ai, Devin, Replit Agents) and have no local or self-hosted agent state to inspect.

## Primary use cases

### UC-0 — Browse a local Claude Code setup
*Casey runs Claude Code on her Mac, with `~/.claude/skills/`, `~/.claude/projects/...`, and a few CLAUDE.md files scattered across repos. She adds a Local host pointing at `~/.claude`, and another at her active project root. Same browser, same viewer, no SSH. Useful even when there's no remote box.*

### UC-1 — Live-edit a CLAUDE.md from the Mac
*Sam runs Claude Code on a $40/mo VPS. They want to tweak the project's `CLAUDE.md` to refine the agent's behavior. Today: SSH, vim, save, hope. With Rookery: open the file in a real editor, with preview, save in one click. Total time: 30 seconds vs. 3 minutes.*

### UC-2 — Inspect agent memory mid-run
*Priya is running a long-form coding task and wants to know what the agent has learned so far. The agent stores transcript and memory in a SQLite file. With Rookery: open the DB, browse the `memories` table, see exactly what's in there. No `sqlite3` CLI gymnastics.*

### UC-3 — Schedule a nightly skill run
*Marco wants his agent to refresh a research dataset every night at 2am. With Rookery: open the Cron tab, pick a schedule from the dropdown, paste the command, save. View tomorrow's run output the next morning.*

### UC-4 — Install a community skill
*Lin downloads a `pdf-extract.skill` from a community repo. With Rookery: drag-drop into the Skills pane on her server profile; the app SFTPs it to `~/.claude/skills/pdf-extract/` and confirms the install. The next agent run picks it up.*

### UC-5 — Spawn a one-off agent for a task
*Daniel wants to kick off a refactoring agent on the server without opening a terminal. With Rookery: hit "New Agent", paste the task into a prompt box, click run. The app spawns a `tmux` session, streams output back to the Mac.*

### UC-6 — Manage three servers at once
*Eli runs experiments across three boxes. With Rookery: a sidebar of host profiles, click to switch, see each box's recent file changes and cron history side-by-side.*

## Anti-use-cases (explicit)

- **"I want Rookery to run an agent for me."** → It doesn't. Run Claude Code (or whatever) yourself; Rookery is the operator surface around the agent's state. Local mode just means we read the same files from the same Mac you ran the agent on.
- **"I want a general SSH terminal."** → Use Termius, Tabby, or iTerm2.
- **"I want to manage agents across a fleet of cloud-managed VMs."** → Rookery scales to ~10 hosts. For 100+, use proper cloud orchestration.
- **"I want a web dashboard."** → Rookery is a native Mac app, not a hosted UI. (LangSmith, AgentOps cover the hosted-dashboard space.)

## Success signals
- A user can connect, edit a remote `.md`, and see the change reflected in <60 seconds from app launch.
- A user has zero need to open a terminal for the canonical happy-path tasks above.
- A user can manage 3+ hosts without confusion about which one they're acting on.
