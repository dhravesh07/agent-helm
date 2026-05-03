import SwiftUI

struct ContentView: View {
    @Bindable var hostStore: HostStore
    @State private var selectedHostId: HostProfile.ID?
    @State private var sessions: [HostProfile.ID: SessionState] = [:]

    private var currentSession: SessionState? {
        guard let id = selectedHostId else { return nil }
        return sessions[id]
    }

    var body: some View {
        NavigationSplitView {
            HostListView(store: hostStore, selection: $selectedHostId)
                .navigationTitle("Rookery")
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } content: {
            if let session = currentSession {
                Group {
                    switch session.surface {
                    case .files:
                        FileBrowserView(session: session)
                    case .cron:
                        CronView(session: session)
                    }
                }
                .navigationTitle(session.profile.name)
                .navigationSubtitle(session.profile.workspaces.first?.path ?? "")
                .toolbar {
                    surfaceToolbar(session: session)
                    connectionToolbar(session: session)
                }
                .navigationSplitViewColumnWidth(min: session.surface == .cron ? 720 : 360, ideal: 480)
            } else {
                ContentUnavailableView(
                    "Select a host",
                    systemImage: "macbook.and.iphone",
                    description: Text("Pick a host from the sidebar, or add one with the + button.")
                )
            }
        } detail: {
            if let session = currentSession {
                switch session.surface {
                case .files:
                    FileEditorView(session: session)
                case .cron:
                    EmptyView()  // cron is a single-pane surface
                }
            } else {
                welcome
            }
        }
        .onChange(of: selectedHostId, initial: true) { _, newId in
            ensureSession(for: newId)
        }
    }

    private func ensureSession(for id: HostProfile.ID?) {
        guard let id,
              let profile = hostStore.hosts.first(where: { $0.id == id }) else { return }

        let session: SessionState
        if let existing = sessions[id] {
            session = existing
        } else {
            session = SessionState(profile: profile)
            sessions[id] = session
        }

        // Auto-connect on selection. Local connections are instant; remote ones
        // kick off the async connect and surface progress via the toolbar spinner.
        // Skip if already connecting/connected, or if the user just hit a hard
        // failure — they need to retry manually so we don't loop on a bad config.
        switch session.status {
        case .disconnected:
            Task { await session.connect() }
        case .connecting, .connected, .reconnecting, .failed:
            break
        }
    }

    @ToolbarContentBuilder
    private func surfaceToolbar(session: SessionState) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Surface", selection: Bindable(session).surface) {
                ForEach(HostSurface.allCases) { surface in
                    Label(surface.label, systemImage: surface.systemImage).tag(surface)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .disabled(session.status != .connected)
            .accessibilityLabel("Host surface")
            .help("Switch between file browsing and cron management")
        }
    }

    @ToolbarContentBuilder
    private func connectionToolbar(session: SessionState) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch session.status {
            case .connected:
                Button {
                    Task { await session.disconnect() }
                } label: {
                    Label(
                        session.profile.kind == .local ? "Close" : "Disconnect",
                        systemImage: "bolt.slash"
                    )
                }
                .rookeryGlassButton()
                .help(session.profile.kind == .local ? "Close folder" : "Disconnect from host")
            case .connecting, .reconnecting:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(session.status == .reconnecting ? "Reconnecting" : "Connecting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .disconnected, .failed:
                Button {
                    Task { await session.connect() }
                } label: {
                    Label(
                        session.profile.kind == .local ? "Open" : "Connect",
                        systemImage: "bolt"
                    )
                }
                .rookeryGlassButtonProminent()
                .help(session.profile.kind == .local ? "Open folder" : "Connect to host")
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: RookerySpacing.md) {
            Image(systemName: "tree.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 4) {
                Text("Rookery")
                    .font(.system(.title, weight: .semibold))
                Text("Read what your AI agents wrote.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
