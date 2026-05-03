import SwiftUI

@main
struct RookeryApp: App {
    @State private var hostStore = HostStore()

    var body: some Scene {
        WindowGroup("Rookery") {
            ContentView(hostStore: hostStore)
                .frame(minWidth: 1000, minHeight: 660)
        }
        // Title bar and toolbar in a single combined row — the standard look
        // for Mac inspector apps (Xcode, Mail, Notes). See macos-window-styling.md.
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) { /* host creation lives in the sidebar */ }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .rookeryRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let rookeryRefresh = Notification.Name("RookeryRefresh")
}
