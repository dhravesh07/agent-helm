import Foundation
import Observation

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

@Observable
@MainActor
final class SessionState {
    let profile: HostProfile
    var status: ConnectionStatus = .disconnected
    var rootPath: String
    var entries: [RemoteFileEntry] = []
    var selectedFile: RemoteFileEntry?
    var fileContents: String?
    var lastError: String?

    private let service = SSHService()

    init(profile: HostProfile) {
        self.profile = profile
        self.rootPath = profile.rootPath
    }

    func connect() async {
        status = .connecting
        lastError = nil
        do {
            try await service.connect(profile: profile)
            if rootPath == "~" || rootPath.isEmpty {
                rootPath = (try? await service.resolveHome()) ?? "/"
            }
            status = .connected
            await refresh()
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func disconnect() async {
        await service.disconnect()
        status = .disconnected
        entries = []
        selectedFile = nil
        fileContents = nil
    }

    func refresh() async {
        guard case .connected = status else { return }
        do {
            entries = try await service.listDirectory(at: rootPath)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func navigate(to path: String) async {
        rootPath = path
        await refresh()
    }

    func navigateUp() async {
        let parent = (rootPath as NSString).deletingLastPathComponent
        if !parent.isEmpty, parent != rootPath {
            await navigate(to: parent)
        }
    }

    func openFile(_ entry: RemoteFileEntry) async {
        selectedFile = entry
        fileContents = nil
        guard !entry.isDirectory else { return }
        do {
            fileContents = try await service.readTextFile(at: entry.path)
        } catch {
            fileContents = nil
            lastError = error.localizedDescription
        }
    }
}
