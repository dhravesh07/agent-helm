import SwiftUI

struct FileBrowserView: View {
    @Bindable var session: SessionState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                Task { await session.navigateUp() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(session.status != .connected)
            .help("Parent directory")

            Text(session.rootPath)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await session.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(session.status != .connected)
            .help("Refresh")
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .disconnected:
            placeholder("Not connected", systemImage: "wifi.slash")
        case .connecting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Connecting…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            placeholder(msg, systemImage: "exclamationmark.triangle")
        case .connected:
            if session.entries.isEmpty {
                placeholder("Empty directory", systemImage: "tray")
            } else {
                List(session.entries, selection: Binding(
                    get: { session.selectedFile?.id },
                    set: { newId in
                        guard let id = newId,
                              let entry = session.entries.first(where: { $0.id == id }) else { return }
                        Task {
                            if entry.isDirectory {
                                await session.navigate(to: entry.path)
                            } else {
                                await session.openFile(entry)
                            }
                        }
                    }
                )) { entry in
                    HStack {
                        Image(systemName: icon(for: entry))
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            .frame(width: 16)
                        Text(entry.name)
                        Spacer()
                        if !entry.isDirectory, let size = entry.size {
                            Text(byteCount(size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(entry.id)
                }
            }
        }
    }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func icon(for entry: RemoteFileEntry) -> String {
        if entry.isDirectory { return "folder" }
        if entry.isMarkdown { return "doc.text" }
        return "doc"
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
