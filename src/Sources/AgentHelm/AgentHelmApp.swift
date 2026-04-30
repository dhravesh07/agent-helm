import SwiftUI

@main
struct AgentHelmApp: App {
    var body: some Scene {
        WindowGroup("Agent Helm") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection…") {
                    // Wired up in v0.1.
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
