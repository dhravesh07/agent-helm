import SwiftUI

struct HostListView: View {
    @Bindable var store: HostStore
    @Binding var selection: HostProfile.ID?
    @State private var showingForm = false
    @State private var editingHost: HostProfile?

    var body: some View {
        Group {
            if store.hosts.isEmpty {
                emptyState
            } else {
                hostList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add host", systemImage: "plus")
                }
                .help("Add a new local folder or remote SSH host")
            }
        }
        .sheet(isPresented: $showingForm) {
            HostFormView(mode: .create) { newHost in
                store.add(newHost)
                selection = newHost.id
            }
        }
        .sheet(item: $editingHost) { host in
            HostFormView(mode: .edit(host)) { updated in
                store.update(updated)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: RookerySpacing.md) {
            Image(systemName: "tree.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 4) {
                Text("No hosts yet")
                    .font(.headline)
                Text("Add a folder on this Mac\nor a Linux server over SSH.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingForm = true
            } label: {
                Label("Add host", systemImage: "plus")
            }
            .rookeryGlassButtonProminent()
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - List

    private var hostList: some View {
        List(selection: $selection) {
            Section {
                ForEach(store.hosts) { host in
                    hostRow(host)
                        .tag(Optional(host.id))
                        .contextMenu {
                            Button {
                                editingHost = host
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.remove(id: host.id)
                                if selection == host.id { selection = nil }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Hosts")
            }
        }
    }

    private func hostRow(_ host: HostProfile) -> some View {
        HStack(spacing: RookerySpacing.sm) {
            Image(systemName: host.kind.systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle(for: host))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(host.name), \(host.kind.displayName), \(subtitle(for: host))")
    }

    private func subtitle(for host: HostProfile) -> String {
        switch host.kind {
        case .local:
            if host.workspaces.count > 1 {
                return "\(host.workspaces.count) workspaces"
            }
            return host.workspaces.first?.path ?? "Local folder"
        case .remote:
            return "\(host.username)@\(host.hostname):\(host.port)"
        }
    }
}
