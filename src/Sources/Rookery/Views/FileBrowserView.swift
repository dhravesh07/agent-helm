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
            if autoRefresh {
                pollTask?.cancel()
                pollTask = Task { await runPollLoop() }
            }
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .rookeryRefresh)) { _ in
            Task { await session.refresh() }
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            if session.profile.workspaces.count > 1 {
                workspacePicker
                    .padding(.horizontal, RookerySpacing.md)
                    .padding(.top, RookerySpacing.sm)
            }
            pathRow
                .padding(.horizontal, RookerySpacing.md)
                .padding(.vertical, RookerySpacing.sm)
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
        .accessibilityLabel("Active workspace")
    }

    private var pathRow: some View {
        HStack(spacing: RookerySpacing.sm) {
            Button {
                Task { await session.navigateUp() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(session.status != .connected)
            .help("Parent directory")
            .accessibilityLabel("Go up one directory")

            Text(session.rootPath)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .accessibilityLabel("Current path")
                .accessibilityValue(session.rootPath)

            Toggle(isOn: $autoRefresh) {
                Image(systemName: autoRefresh ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                    .symbolRenderingMode(.hierarchical)
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .disabled(session.status != .connected)
            .help(autoRefresh ? "Auto-refresh on — polling every 5 s" : "Auto-refresh off")
            .accessibilityLabel("Auto refresh")

            Button {
                Task { await session.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(session.status != .connected)
            .help("Refresh now (⌘R)")
            .accessibilityLabel("Refresh listing")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .disconnected:
            ContentUnavailableView(
                "Not connected",
                systemImage: "wifi.slash",
                description: Text("Use the Connect button in the toolbar.")
            )
        case .connecting:
            statusPane(spinner: true, primary: "Connecting", secondary: nil)
        case .reconnecting:
            statusPane(
                spinner: true,
                primary: "Reconnecting",
                secondary: "Recovering from sleep or network change…"
            )
        case .failed(let msg):
            ContentUnavailableView {
                Label("Couldn't connect", systemImage: "exclamationmark.triangle")
            } description: {
                Text(msg)
                    .font(.caption)
                    .lineLimit(4)
            } actions: {
                Button("Retry") {
                    Task { await session.connect() }
                }
                .rookeryGlassButton()
            }
        case .connected:
            if session.entries.isEmpty {
                ContentUnavailableView(
                    "Empty directory",
                    systemImage: "tray",
                    description: Text("No files in this folder.")
                )
            } else {
                fileList
            }
        }
    }

    private var fileList: some View {
        List(session.entries, selection: $highlightedId) { entry in
            entryRow(entry)
                .tag(entry.id)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    activate(entry)
                }
        }
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

    private func entryRow(_ entry: RemoteFileEntry) -> some View {
        HStack(spacing: RookerySpacing.sm) {
            Image(systemName: icon(for: entry))
                .foregroundStyle(iconColor(for: entry))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)
            Text(entry.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if !entry.isDirectory, let size = entry.size {
                Text(byteCount(size))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
        .accessibilityHint("Double-click or press Return to open")
    }

    private func activate(_ entry: RemoteFileEntry) {
        Task {
            if entry.isDirectory {
                await session.navigate(to: entry.path)
            } else {
                await session.openFile(entry)
            }
        }
    }

    private func activateHighlighted() {
        guard let id = highlightedId,
              let entry = session.entries.first(where: { $0.id == id }) else { return }
        activate(entry)
    }

    // MARK: - Helpers

    private func statusPane(spinner: Bool, primary: String, secondary: String?) -> some View {
        VStack(spacing: RookerySpacing.sm) {
            if spinner {
                ProgressView()
                    .controlSize(.large)
            }
            Text(primary)
                .font(.headline)
            if let secondary {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func icon(for entry: RemoteFileEntry) -> String {
        if entry.isDirectory { return "folder.fill" }
        switch entry.previewableKind {
        case .markdown: return "doc.text.fill"
        case .json, .jsonl: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .sqlite: return "cylinder.split.1x2.fill"
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        case .sourceText: return "doc.fill"
        }
    }

    private func iconColor(for entry: RemoteFileEntry) -> Color {
        if entry.isDirectory { return .blue }
        switch entry.previewableKind {
        case .markdown: return .accentColor
        case .json, .jsonl: return .orange
        case .xml: return .purple
        case .sqlite: return .indigo
        case .image: return .pink
        case .pdf: return .red
        case .sourceText: return .secondary
        }
    }

    private func accessibilityLabel(for entry: RemoteFileEntry) -> String {
        if entry.isDirectory {
            return "\(entry.name), folder"
        }
        if let size = entry.size {
            return "\(entry.name), \(byteCount(size))"
        }
        return entry.name
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
