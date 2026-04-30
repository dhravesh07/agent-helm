import SwiftUI

struct ContentView: View {
    @Bindable var hostStore: HostStore
    @State private var selectedHostId: HostProfile.ID?
    @State private var sessions: [HostProfile.ID: SessionState] = [:]

    private var currentSession: SessionState? {
        guard let id = selectedHostId,
              let profile = hostStore.hosts.first(where: { $0.id == id }) else { return nil }
        if let existing = sessions[id] { return existing }
        let new = SessionState(profile: profile)
        sessions[id] = new
        return new
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
                MarkdownViewerView(entry: session.selectedFile, contents: session.fileContents)
            } else {
                welcome
            }
        }
        .onChange(of: selectedHostId) { _, _ in
            // The session is created lazily by `currentSession`; views observe it directly.
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
