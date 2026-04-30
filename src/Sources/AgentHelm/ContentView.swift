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
                .navigationTitle("Agent Helm")
                .frame(minWidth: 220)
        } content: {
            if let session = currentSession {
                FileBrowserView(session: session)
                    .navigationTitle(session.profile.name)
                    .toolbar { connectionToolbar(session: session) }
                    .frame(minWidth: 320)
            } else {
                Text("Select or add a host")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 320)
            }
        } detail: {
            if let session = currentSession {
                FileEditorView(session: session)
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
        case .connecting, .connected, .failed:
            break
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
                    Label(session.profile.kind == .local ? "Close" : "Disconnect", systemImage: "bolt.slash")
                }
            case .connecting:
                ProgressView().controlSize(.small)
            case .disconnected, .failed:
                Button {
                    Task { await session.connect() }
                } label: {
                    Label(session.profile.kind == .local ? "Open" : "Connect", systemImage: "bolt")
                }
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 12) {
            Image(systemName: "sailboat")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tertiary)
            Text("Agent Helm")
                .font(.title)
            Text("Add a host in the sidebar to begin.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
