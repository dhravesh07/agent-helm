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
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !hostname.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !privateKeyPath.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(portString) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Identity") {
                    TextField("Display name", text: $name)
                    TextField("Hostname or IP", text: $hostname)
                    TextField("Port", text: $portString)
                    TextField("Username", text: $username)
                }
                Section("Authentication") {
                    HStack {
                        TextField("Private key path", text: $privateKeyPath)
                        Button("Choose…") { pickKeyFile() }
                    }
                    Text("Supports OpenSSH ed25519 and RSA keys. Encrypted keys aren't supported in v0.0.3.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Root path") {
                    TextField("Root directory on remote", text: $rootPath)
                    Text("Default `~` resolves to the user's home directory after connect.")
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
        .frame(minWidth: 480, minHeight: 460)
        .navigationTitle(titleText)
        .onAppear { hydrate() }
    }

    private func hydrate() {
        guard case .edit(let host) = mode else { return }
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
}
