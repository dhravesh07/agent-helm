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
                if entry.isMarkdown && session.bufferState.isText {
                    modeToggle
                }
                Spacer()
                saveStatusLabel
                if session.bufferState.isText {
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
            if entry.isMarkdown && session.viewMode == .preview {
                markdownPreview
            } else {
                sourceEditor(isMarkdown: entry.isMarkdown)
            }
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

    private var markdownPreview: some View {
        ScrollView {
            let attributed = (try? AttributedString(
                markdown: session.editText,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )) ?? AttributedString(session.editText)
            Text(attributed)
                .textSelection(.enabled)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }

    private func sourceEditor(isMarkdown: Bool) -> some View {
        TextEditor(text: $session.editText)
            .font(isMarkdown ? .body : .system(.body, design: .monospaced))
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
