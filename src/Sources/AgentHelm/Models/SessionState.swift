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
    static let maxFileSize: UInt64 = 5 * 1024 * 1024  // 5 MB cap for in-app editing

    let profile: HostProfile
    var status: ConnectionStatus = .disconnected
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

    private let service: any RemoteFileService

    init(profile: HostProfile) {
        self.profile = profile
        self.rootPath = profile.rootPath
        switch profile.kind {
        case .local:
            self.service = LocalFileService()
        case .remote:
            self.service = SSHService()
        }
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
            // Naive guard: refuse to swap files with unsaved changes.
            // A confirmation dialog is the right next polish; for now the user
            // sees the dirty state and can save or discard before switching.
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
            // Refresh the directory listing so size in the file tree updates.
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

    // MARK: - Internal

    private func clearFileBuffer() {
        bufferState = .empty
        editText = ""
        saveStatus = .idle
    }
}
