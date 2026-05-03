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
            .alert("File changed on remote", isPresented: Binding(
                get: { session.pendingConflict != nil },
                set: { if !$0 { session.pendingConflict = nil } }
            ), presenting: session.pendingConflict) { _ in
                Button("Reload", role: .cancel) {
                    Task { await session.resolveConflictByReloading() }
                }
                Button("Overwrite", role: .destructive) {
                    Task { await session.resolveConflictByOverwriting() }
                }
                Button("Keep editing") {
                    session.pendingConflict = nil
                }
            } message: { _ in
                Text("Another writer (likely your agent) modified this file while you were editing. Reload to start over with the remote version, or Overwrite to clobber it with your changes.")
            }
        } else {
            placeholder
        }
    }

    // MARK: - Header

    private func header(for entry: RemoteFileEntry) -> some View {
        VStack(alignment: .leading, spacing: RookerySpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: RookerySpacing.sm) {
                Text(entry.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if session.isDirty {
                    Label("Modified", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel("Unsaved changes")
                }
                Spacer()
                Text(entry.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityHidden(true)
            }
            HStack(spacing: RookerySpacing.md) {
                viewModeToggle(for: entry)
                Spacer()
                saveStatusLabel
                if entry.previewableKind.isEditableText && session.bufferState.isText {
                    Button("Discard") {
                        session.discardChanges()
                    }
                    .rookeryGlassButton()
                    .disabled(!session.isDirty || session.saveStatus == .saving)
                    .help("Revert to the version on disk")

                    Button {
                        Task { await session.save() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .rookeryGlassButtonProminent()
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!session.canSave)
                    .help("Save changes (⌘S)")
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, RookerySpacing.lg)
        .padding(.vertical, RookerySpacing.md)
    }

    @ViewBuilder
    private func viewModeToggle(for entry: RemoteFileEntry) -> some View {
        let modes = entry.previewableKind.availableViewModes
        // Show toggle when there are 2+ modes AND the buffer is in a renderable
        // state — text for editable kinds, sqlite for the DB inspector.
        let bufferReady: Bool = {
            if session.bufferState.isText { return true }
            if case .sqlite = session.bufferState { return true }
            return false
        }()
        if modes.count >= 2 && bufferReady {
            Picker("View", selection: $session.viewMode) {
                ForEach(modes) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: CGFloat(modes.count) * 90 + 20)
            .labelsHidden()
        }
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
        case .sqlite(let localPath, _):
            SQLiteBrowserView(localPath: localPath, mode: session.viewMode)
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
        case (.json, .graph):
            JSONGraphView(text: $session.editText)
        case (.jsonl, .transcript):
            JSONLTranscriptView(raw: session.editText)
        case (.json, .formatted):
            JSONPreviewView(raw: session.editText)
        case (.xml, .preview):
            XMLPreviewView(raw: session.editText)
        default:
            sourceEditor(for: entry)
        }
    }

    private func sourceEditor(for entry: RemoteFileEntry) -> some View {
        let isProse = entry.previewableKind == .markdown
        return LineNumberedTextEditor(
            text: $session.editText,
            isMonospaced: !isProse,
            languageSpec: SyntaxLanguages.spec(for: entry)
        )
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
