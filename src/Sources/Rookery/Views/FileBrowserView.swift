import SwiftUI

struct FileBrowserView: View {
    @Bindable var session: SessionState
    @State private var highlightedId: RemoteFileEntry.ID?
    @State private var autoRefresh: Bool = false
    @State private var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(5)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onChange(of: autoRefresh) { _, newValue in
            pollTask?.cancel()
            if newValue {
                pollTask = Task { await runPollLoop() }
            }
        }
        .onChange(of: session.rootPath) { _, _ in
            // Restart the loop on path change so the next refresh reflects the
            // new directory immediately.
            if autoRefresh {
                pollTask?.cancel()
                pollTask = Task { await runPollLoop() }
            }
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    private func runPollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            if Task.isCancelled { return }
            if case .connected = session.status {
                await session.refresh()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            if session.profile.workspaces.count > 1 {
                workspacePicker
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            HStack(spacing: 8) {
                Button {
                    Task { await session.navigateUp() }
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(session.status != .connected)
                .help("Parent directory")

                Text(session.rootPath)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Toggle(isOn: $autoRefresh) {
                    Image(systemName: autoRefresh ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .disabled(session.status != .connected)
                .help(autoRefresh ? "Auto-refresh on (every 5s)" : "Auto-refresh off")

                Button {
                    Task { await session.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(session.status != .connected)
                .help("Refresh once")
            }
            .padding(8)
        }
    }

    private var workspacePicker: some View {
        Picker("Workspace", selection: Binding(
            get: { session.currentWorkspaceId },
            set: { newId in
                guard let workspace = session.profile.workspaces.first(where: { $0.id == newId }) else { return }
                Task { await session.switchWorkspace(workspace) }
            }
        )) {
            ForEach(session.profile.workspaces) { ws in
                Text(ws.name).tag(ws.id)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(session.status != .connected)
    }

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .disconnected:
            placeholder("Not connected", systemImage: "wifi.slash")
        case .connecting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Connecting…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .reconnecting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Reconnecting after sleep/wake…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            placeholder(msg, systemImage: "exclamationmark.triangle")
        case .connected:
            if session.entries.isEmpty {
                placeholder("Empty directory", systemImage: "tray")
            } else {
                List(session.entries, selection: $highlightedId) { entry in
                    HStack {
                        Image(systemName: icon(for: entry))
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            .frame(width: 16)
                        Text(entry.name)
                        Spacer()
                        if !entry.isDirectory, let size = entry.size {
                            Text(byteCount(size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(entry.id)
                    .contentShape(Rectangle())
                    // Single click highlights via List's selection binding above.
                    // Double click navigates into a folder or opens a file.
                    .onTapGesture(count: 2) {
                        Task {
                            if entry.isDirectory {
                                await session.navigate(to: entry.path)
                            } else {
                                await session.openFile(entry)
                            }
                        }
                    }
                }
                // Enter / Return on the highlighted row also activates it,
                // matching Finder's keyboard behavior.
                .onKeyPress(.return) {
                    activateHighlighted()
                    return .handled
                }
                .onChange(of: session.rootPath) { _, _ in
                    highlightedId = nil
                }
                .onChange(of: session.selectedFile?.id) { _, newId in
                    if let newId { highlightedId = newId }
                }
            }
        }
    }

    private func activateHighlighted() {
        guard let id = highlightedId,
              let entry = session.entries.first(where: { $0.id == id }) else { return }
        Task {
            if entry.isDirectory {
                await session.navigate(to: entry.path)
            } else {
                await session.openFile(entry)
            }
        }
    }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func icon(for entry: RemoteFileEntry) -> String {
        if entry.isDirectory { return "folder" }
        if entry.isMarkdown { return "doc.text" }
        return "doc"
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
