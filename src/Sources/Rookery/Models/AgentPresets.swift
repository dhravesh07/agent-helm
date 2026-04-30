import Foundation

/// Known on-disk locations where popular AI coding agents store state.
/// Used by the host form's "Add common workspaces" flow so the user
/// doesn't have to type these from memory.
struct AgentPreset: Identifiable, Hashable {
    let id: String              // stable name, e.g. "claude-code"
    let displayName: String
    let workspaces: [PresetWorkspace]
}

struct PresetWorkspace: Hashable {
    let name: String
    let path: String
}

enum AgentPresets {
    static let all: [AgentPreset] = [
        AgentPreset(
            id: "claude-code",
            displayName: "Claude Code",
            workspaces: [
                PresetWorkspace(name: "Claude home", path: "~/.claude"),
                PresetWorkspace(name: "Skills",      path: "~/.claude/skills"),
                PresetWorkspace(name: "Projects",    path: "~/.claude/projects"),
            ]
        ),
        AgentPreset(
            id: "aider",
            displayName: "Aider",
            workspaces: [
                PresetWorkspace(name: "Aider config",  path: "~/.aider"),
                PresetWorkspace(name: "Aider history", path: "~/.aider.input.history"),
            ]
        ),
        AgentPreset(
            id: "opencode",
            displayName: "OpenCode",
            workspaces: [
                PresetWorkspace(name: "OpenCode home", path: "~/.opencode"),
                PresetWorkspace(name: "OpenCode config", path: "~/.config/opencode"),
            ]
        ),
        AgentPreset(
            id: "openclaude",
            displayName: "OpenClaude",
            workspaces: [
                PresetWorkspace(name: "OpenClaude home", path: "~/.openclaude"),
            ]
        ),
        AgentPreset(
            id: "continue",
            displayName: "Continue",
            workspaces: [
                PresetWorkspace(name: "Continue home", path: "~/.continue"),
            ]
        ),
        AgentPreset(
            id: "cline",
            displayName: "Cline",
            workspaces: [
                PresetWorkspace(name: "Cline home", path: "~/.cline"),
            ]
        ),
        AgentPreset(
            id: "codex",
            displayName: "Codex (OpenAI)",
            workspaces: [
                PresetWorkspace(name: "Codex home", path: "~/.codex"),
                PresetWorkspace(name: "Codex config", path: "~/.config/codex"),
            ]
        ),
    ]

    static func preset(byId id: String) -> AgentPreset? {
        all.first { $0.id == id }
    }
}
