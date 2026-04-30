import SwiftUI

@main
struct RookeryApp: App {
    @State private var hostStore = HostStore()

    var body: some Scene {
        WindowGroup("Rookery") {
            ContentView(hostStore: hostStore)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
