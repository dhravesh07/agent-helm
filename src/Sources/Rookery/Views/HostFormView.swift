import SwiftUI
import AppKit

struct HostFormView: View {
    enum Mode {
        case create
        case edit(HostProfile)
    }

    let mode: Mode
    let onSubmit: (HostProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: HostKind = .remote
    @State private var name: String = ""
    @State private var hostname: String = ""
    @State private var portString: String = "22"
    @State private var username: String = ""
    @State private var privateKeyPath: String = ""
    @State private var workspaces: [Workspace] = [Workspace(name: "Root", path: "~")]

    private var existingId: UUID? {
        if case .edit(let host) = mode { return host.id }
        return nil
    }

    private var titleText: String {
        if case .edit = mode { return "Edit Host" }
        return "Add Host"
    }

    private var canSubmit: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
        guard !workspaces.isEmpty else { return false }
        guard workspaces.allSatisfy({
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.path.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return false }
        switch kind {
        case .local:
            return true
        case .remote:
            return !hostname.trimmingCharacters(in: .whitespaces).isEmpty
                && !username.trimmingCharacters(in: .whitespaces).isEmpty
                && !privateKeyPath.trimmingCharacters(in: .whitespaces).isEmpty
                && Int(portString) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Connection") {
                    Picker("Kind", selection: $kind) {
                        ForEach(HostKind.allCases) { k in
                            Label(k.displayName, systemImage: k.systemImage).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Display name", text: $name)
                }

                if kind == .remote {
                    Section("Server") {
                        TextField("Hostname or IP", text: $hostname)
                        TextField("Port", text: $portString)
                        TextField("Username", text: $username)
                    }
                    Section("Authentication") {
                        HStack {
                            TextField("Private key path", text: $privateKeyPath)
                            Button("Choose…") { pickKeyFile() }
                        }
                        Text("Supports OpenSSH ed25519 and RSA keys. Encrypted keys aren't supported yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(workspaceSectionTitle) {
                    workspaceEditor
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 540)
        .navigationTitle(titleText)
        .onAppear { hydrate() }
    }

    private var workspaceSectionTitle: String {
        kind == .local ? "Workspaces (folders on this Mac)" : "Workspaces (paths on remote)"
    }

    private var workspaceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($workspaces) { $workspace in
                HStack(spacing: 6) {
                    TextField("Name", text: $workspace.name)
                        .frame(width: 110)
                    TextField(kind == .local ? "Folder path" : "Remote path", text: $workspace.path)
                    if kind == .local {
                        Button {
                            pickFolder(into: $workspace.path)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }
                    Button {
                        remove(workspace)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(workspaces.count <= 1)
                }
            }
            HStack(spacing: 12) {
                Button {
                    workspaces.append(Workspace(name: "New", path: "~"))
                } label: {
                    Label("Add workspace", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Menu {
                    ForEach(AgentPresets.all) { preset in
                        Button(preset.displayName) {
                            applyPreset(preset)
                        }
                    }
                } label: {
                    Label("Add preset…", systemImage: "wand.and.stars")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
            }
            Text(kind == .local
                 ? "Add one folder per area you want to inspect — e.g. ~/.claude, your project root, ~/.config/aider."
                 : "Add a workspace per directory you operate in on the remote — Skills, project root, agent state, etc. `~` resolves to the user's home after connect.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func remove(_ workspace: Workspace) {
        guard workspaces.count > 1 else { return }
        workspaces.removeAll { $0.id == workspace.id }
    }

    private func applyPreset(_ preset: AgentPreset) {
        // Drop the placeholder "Root" workspace if it's the only one and untouched.
        if workspaces.count == 1, workspaces[0].name == "Root", workspaces[0].path == "~" {
            workspaces.removeAll()
        }
        for w in preset.workspaces {
            // Don't add duplicates by path.
            if workspaces.contains(where: { $0.path == w.path }) { continue }
            workspaces.append(Workspace(name: w.name, path: w.path))
        }
    }

    private func hydrate() {
        guard case .edit(let host) = mode else { return }
        kind = host.kind
        name = host.name
        hostname = host.hostname
        portString = String(host.port)
        username = host.username
        privateKeyPath = host.privateKeyPath
        workspaces = host.workspaces.isEmpty ? [Workspace(name: "Root", path: "~")] : host.workspaces
    }

    private func submit() {
        let profile = HostProfile(
            id: existingId ?? UUID(),
            kind: kind,
            name: name,
            hostname: hostname,
            port: Int(portString) ?? 22,
            username: username,
            privateKeyPath: privateKeyPath,
            workspaces: workspaces
        )
        onSubmit(profile)
        dismiss()
    }

    private func pickKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSString("~/.ssh").expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }

    private func pickFolder(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }
}
