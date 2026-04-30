import SwiftUI

@main
struct AgentHelmApp: App {
    @State private var hostStore = HostStore()

    var body: some Scene {
        WindowGroup("Agent Helm") {
            ContentView(hostStore: hostStore)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
