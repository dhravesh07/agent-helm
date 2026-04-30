import Foundation
import Observation
import AppKit
import Network

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(String)
}

@Observable
@MainActor
final class SessionState {
    static let maxFileSize: UInt64 = 5 * 1024 * 1024  // 5 MB cap for in-app editing

    let profile: HostProfile
    var status: ConnectionStatus = .disconnected
    var currentWorkspaceId: UUID
    var rootPath: String
    var entries: [RemoteFileEntry] = []
    var selectedFile: RemoteFileEntry?
    var bufferState: FileBufferState = .empty
    var editText: String = ""
    var viewMode: FileViewMode = .preview
    var saveStatus: SaveStatus = .idle
    var lastError: String?

    var isDirty: Bool {
        guard case .text(let original) = bufferState else { return false }
        return editText != original
    }

    var canSave: Bool {
        bufferState.isText && isDirty && saveStatus != .saving
    }

    var currentWorkspace: Workspace {
        profile.workspaces.first(where: { $0.id == currentWorkspaceId })
            ?? profile.workspaces.first
            ?? Workspace(name: "Root", path: "~")
    }

    private let service: any RemoteFileService
    private var lifecycleObservers: [NSObjectProtocol] = []
    private let pathMonitor = NWPathMonitor()
    private var lastNetworkSatisfied = true

    init(profile: HostProfile) {
        self.profile = profile
        let firstWorkspace = profile.workspaces.first ?? Workspace(name: "Root", path: "~")
        self.currentWorkspaceId = firstWorkspace.id
        self.rootPath = firstWorkspace.path
        switch profile.kind {
        case .local:
            self.service = LocalFileService()
        case .remote:
            self.service = SSHService()
        }
        observeSystemEvents()
    }

    /// Called by ContentView when the session is being torn down (e.g. host
    /// removed). Removes notification observers and stops the path monitor.
    func cancelLifecycleObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        for obs in lifecycleObservers { nc.removeObserver(obs) }
        lifecycleObservers = []
        pathMonitor.cancel()
    }

    // MARK: - Connection

    func connect() async {
        status = .connecting
        lastError = nil
        do {
            try await service.connect(profile: profile)
            if rootPath == "~" || rootPath.isEmpty {
                rootPath = (try? await service.resolveHome()) ?? "/"
            } else {
                rootPath = (rootPath as NSString).expandingTildeInPath
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
        clearFileBuffer()
    }

    /// Reconnect after a sleep/wake or network-change. Marks status briefly
    /// before going through `connect()` so the UI shows it's working.
    func reconnect() async {
        status = .reconnecting
        await service.disconnect()
        await connect()
    }

    // MARK: - Workspaces

    func switchWorkspace(_ workspace: Workspace) async {
        if isDirty {
            lastError = "Save your changes before switching workspaces."
            return
        }
        currentWorkspaceId = workspace.id
        rootPath = (workspace.path as NSString).expandingTildeInPath
        clearFileBuffer()
        selectedFile = nil
        await refresh()
    }

    // MARK: - Browsing

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
        clearFileBuffer()
        await refresh()
    }

    func navigateUp() async {
        let parent = (rootPath as NSString).deletingLastPathComponent
        if !parent.isEmpty, parent != rootPath {
            await navigate(to: parent)
        }
    }

    // MARK: - File open / read

    func openFile(_ entry: RemoteFileEntry) async {
        if isDirty {
            lastError = "Save your changes before switching files."
            return
        }
        selectedFile = entry
        clearFileBuffer()
        guard !entry.isDirectory else { return }

        bufferState = .loading
        viewMode = entry.previewableKind.defaultViewMode

        do {
            let meta = try await service.statFile(at: entry.path)
            if meta.size > Self.maxFileSize {
                bufferState = .tooLarge(size: meta.size)
                return
            }
            let data = try await service.readFile(at: entry.path, maxBytes: Int(Self.maxFileSize))

            switch entry.previewableKind {
            case .image:
                bufferState = .image(data: data)
            case .pdf:
                bufferState = .pdf(data: data)
            case .markdown, .json, .xml, .sourceText:
                if let text = String(data: data, encoding: .utf8) {
                    bufferState = .text(original: text)
                    editText = text
                    saveStatus = .idle
                } else {
                    bufferState = .binary(size: meta.size)
                }
            }
        } catch {
            bufferState = .error(message: error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    // MARK: - File save

    func save() async {
        guard case .text(let original) = bufferState, editText != original else { return }
        guard let entry = selectedFile else { return }

        saveStatus = .saving
        do {
            let data = Data(editText.utf8)
            try await service.writeFile(at: entry.path, contents: data)
            bufferState = .text(original: editText)
            saveStatus = .saved(at: Date())
            if case .connected = status {
                if let updated = try? await service.listDirectory(at: rootPath) {
                    entries = updated
                }
            }
        } catch {
            saveStatus = .failed(message: error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func discardChanges() {
        if case .text(let original) = bufferState {
            editText = original
            saveStatus = .idle
        }
    }

    // MARK: - System lifecycle (sleep/wake, network)

    private func observeSystemEvents() {
        let nc = NSWorkspace.shared.notificationCenter

        let wakeObs = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.handleWake() }
        }
        let sleepObs = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.handleSleep() }
        }
        lifecycleObservers = [wakeObs, sleepObs]

        // Network path: mark a transition only when connectivity flips, so we
        // don't reconnect on every WiFi change to the same satisfied state.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.lastNetworkSatisfied && satisfied {
                    await self.handleNetworkRestored()
                }
                self.lastNetworkSatisfied = satisfied
            }
        }
        pathMonitor.start(queue: .main)
    }

    private func handleSleep() async {
        // Note the moment but don't tear down — many sleeps are short and the
        // session might still be alive when we wake. We'll validate on wake.
    }

    private func handleWake() async {
        // Local sessions are unaffected by sleep — the filesystem is right
        // here. (External-volume hosts may have unmounted, but the next
        // listDirectory will surface that.)
        guard profile.kind == .remote else { return }
        guard case .connected = status else { return }
        await reconnect()
    }

    private func handleNetworkRestored() async {
        guard profile.kind == .remote else { return }
        switch status {
        case .connected, .failed:
            // Either we silently lost the socket (now visibly disconnected),
            // or we were stuck in a failed state. Try again.
            await reconnect()
        default:
            break
        }
    }

    // MARK: - Internal

    private func clearFileBuffer() {
        bufferState = .empty
        editText = ""
        saveStatus = .idle
    }
}
