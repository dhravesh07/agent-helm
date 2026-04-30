import SwiftUI

struct HostListView: View {
    @Bindable var store: HostStore
    @Binding var selection: HostProfile.ID?
    @State private var showingForm = false
    @State private var editingHost: HostProfile?

    var body: some View {
        List(selection: $selection) {
            Section("Hosts") {
                if store.hosts.isEmpty {
                    Text("No hosts yet")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(store.hosts) { host in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.name).font(.body)
                            Text("\(host.username)@\(host.hostname):\(host.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(host.id))
                        .contextMenu {
                            Button("Edit") { editingHost = host }
                            Button("Delete", role: .destructive) {
                                store.remove(id: host.id)
                                if selection == host.id { selection = nil }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Host", systemImage: "plus")
                }
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
}
