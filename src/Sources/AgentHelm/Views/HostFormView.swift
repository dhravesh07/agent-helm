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
    @State private var rootPath: String = "~"

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
        let trimmedRoot = rootPath.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedRoot.isEmpty else { return false }
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
                        Text("Supports OpenSSH ed25519 and RSA keys. Encrypted keys aren't supported in v0.0.4.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(kind == .local ? "Folder on this Mac" : "Root path on remote") {
                    HStack {
                        TextField(
                            kind == .local ? "Folder path (e.g. ~/.claude)" : "Root directory",
                            text: $rootPath
                        )
                        if kind == .local {
                            Button("Choose…") { pickFolder() }
                        }
                    }
                    Text(rootPathHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .frame(minWidth: 520, minHeight: 480)
        .navigationTitle(titleText)
        .onAppear { hydrate() }
    }

    private var rootPathHint: String {
        switch kind {
        case .local:
            return "Point at the folder you want to browse — e.g. `~/.claude` for Claude Code, or any project root."
        case .remote:
            return "Default `~` resolves to the user's home directory after connect."
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
        rootPath = host.rootPath
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
            rootPath: rootPath.isEmpty ? "~" : rootPath
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

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            rootPath = url.path
        }
    }
}
