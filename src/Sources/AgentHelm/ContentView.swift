import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Hosts") {
                    Text("No hosts yet")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .navigationTitle("Agent Helm")
            .frame(minWidth: 220)
        } content: {
            Text("Select a host")
                .foregroundStyle(.secondary)
                .frame(minWidth: 280)
        } detail: {
            VStack(spacing: 12) {
                Image(systemName: "sailboat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.tertiary)
                Text("Agent Helm")
                    .font(.title)
                Text("v0.0.1 — scaffold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
