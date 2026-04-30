import SwiftUI

struct FileEditorView: View {
    @Bindable var session: SessionState

    var body: some View {
        if let entry = session.selectedFile {
            VStack(spacing: 0) {
                header(for: entry)
                Divider()
                content(for: entry)
            }
        } else {
            placeholder
        }
    }

    // MARK: - Header

    private func header(for entry: RemoteFileEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.title3.bold())
                if session.isDirty {
                    Text("• Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(entry.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 12) {
                if entry.previewableKind.supportsPreviewToggle && session.bufferState.isText {
                    modeToggle
                }
                Spacer()
                saveStatusLabel
                if entry.previewableKind.isEditableText && session.bufferState.isText {
                    Button("Discard") { session.discardChanges() }
                        .disabled(!session.isDirty || session.saveStatus == .saving)
                    Button {
                        Task { await session.save() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!session.canSave)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var modeToggle: some View {
        Picker("View", selection: $session.viewMode) {
            ForEach(FileViewMode.allCases) { mode in
                Label(mode.label, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .labelsHidden()
    }

    @ViewBuilder
    private var saveStatusLabel: some View {
        switch session.saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Saving…").foregroundStyle(.secondary)
            }
        case .saved(let at):
            Text("Saved \(at, format: .relative(presentation: .named))")
                .foregroundStyle(.secondary)
        case .failed(let msg):
            Text("Save failed: \(msg)")
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for entry: RemoteFileEntry) -> some View {
        switch session.bufferState {
        case .empty:
            placeholder
        case .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .text:
            textBody(for: entry)
        case .image(let data):
            ImagePreviewView(data: data)
        case .pdf(let data):
            PDFPreviewView(data: data)
        case .binary(let size):
            statusPane(
                systemImage: "doc",
                title: "Binary file",
                detail: "\(byteCount(size)) — not shown."
            )
        case .tooLarge(let size):
            statusPane(
                systemImage: "exclamationmark.triangle",
                title: "File too large",
                detail: "\(byteCount(size)) exceeds the 5 MB in-app limit."
            )
        case .error(let msg):
            statusPane(
                systemImage: "exclamationmark.octagon",
                title: "Couldn't open file",
                detail: msg
            )
        }
    }

    @ViewBuilder
    private func textBody(for entry: RemoteFileEntry) -> some View {
        switch (entry.previewableKind, session.viewMode) {
        case (.markdown, .preview):
            MarkdownPreviewView(text: session.editText)
        case (.json, .preview):
            JSONPreviewView(raw: session.editText)
        default:
            sourceEditor(for: entry)
        }
    }

    private func sourceEditor(for entry: RemoteFileEntry) -> some View {
        let isProse = entry.previewableKind == .markdown
        return TextEditor(text: $session.editText)
            .font(isProse ? .body : .system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func statusPane(systemImage: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Select a file to view")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
