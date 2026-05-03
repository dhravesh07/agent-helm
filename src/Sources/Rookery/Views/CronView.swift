import SwiftUI

/// Top-level cron surface: tab between **Entries** (CRUD list + editor) and
/// **History** (parsed mail-spool runs).
struct CronView: View {
    @Bindable var session: SessionState

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            switch session.cron.tab {
            case .entries: CronEntriesPane(session: session)
            case .history: CronHistoryPane(session: session)
            }
        }
        .task(id: session.surface) {
            // Lazy load on first switch into Cron surface.
            guard session.surface == .cron else { return }
            if case .idle = session.cron.status {
                await session.loadCron()
            }
        }
        .task(id: session.cron.tab) {
            guard session.cron.tab == .history else { return }
            if case .idle = session.cron.historyStatus {
                await session.loadCronHistory()
            }
        }
    }

    private var tabBar: some View {
        HStack {
            Picker("Cron tab", selection: $session.cron.tab) {
                ForEach(CronTab.allCases) { tab in
                    Label(tab.label, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)

            Spacer()

            switch session.cron.tab {
            case .entries:
                if session.cron.dirty {
                    Label("Modified", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel("Unsaved cron changes")
                }
                saveStatusLabel
                Button {
                    Task { await session.loadCron() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .rookeryGlassButton()
                .help("Re-read crontab from the host")
                Button {
                    Task { await session.saveCron() }
                } label: {
                    Label("Install crontab", systemImage: "square.and.arrow.down")
                }
                .rookeryGlassButtonProminent()
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!session.cron.dirty || session.cron.saveStatus == .saving)
                .help("Save and install the new crontab (⌘S)")
            case .history:
                Button {
                    Task { await session.loadCronHistory() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rookeryGlassButton()
                .help("Re-read history from the mail spool")
            }
        }
        .padding(.horizontal, RookerySpacing.md)
        .padding(.vertical, RookerySpacing.sm)
    }

    @ViewBuilder
    private var saveStatusLabel: some View {
        switch session.cron.saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Installing…").foregroundStyle(.secondary).font(.caption)
            }
        case .saved(let at):
            Text("Installed \(at, format: .relative(presentation: .named))")
                .foregroundStyle(.secondary).font(.caption)
        case .failed(let msg):
            Text("Failed: \(msg)")
                .foregroundStyle(.red).font(.caption)
                .lineLimit(1).truncationMode(.middle)
        }
    }
}

// MARK: - Entries pane

private struct CronEntriesPane: View {
    @Bindable var session: SessionState

    var body: some View {
        switch session.cron.status {
        case .idle, .loading:
            ProgressView("Loading crontab…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 36))
                    .foregroundStyle(.red.opacity(0.6))
                Text("Couldn't read crontab")
                    .font(.headline)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Retry") {
                    Task { await session.loadCron() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            HSplitView {
                entriesSidebar
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: 480)
                editorPane
                    .frame(minWidth: 360)
            }
        }
    }

    private var entriesSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $session.cron.selectedEntryId) {
                if !session.cron.validationProblems.isEmpty {
                    Section("Validation") {
                        ForEach(session.cron.validationProblems, id: \.self) { problem in
                            Label(problem, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section("Entries (\(session.cron.entries.count))") {
                    if session.cron.entries.isEmpty {
                        Text("No cron entries").foregroundStyle(.secondary).italic()
                    } else {
                        ForEach(session.cron.entries) { entry in
                            CronEntryRow(entry: entry)
                                .tag(entry.id)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button {
                    session.addCronEntry()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                if let id = session.cron.selectedEntryId {
                    Button(role: .destructive) {
                        session.deleteCronEntry(id: id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        if let id = session.cron.selectedEntryId,
           let entry = session.cron.entries.first(where: { $0.id == id }) {
            CronEntryEditor(
                entry: entry,
                onChange: { updated in session.updateCronEntry(updated) },
                onRunNow: { e in
                    Task { await session.runCronNow(e) }
                },
                runNowResult: session.cron.runNowEntryId == id ? session.cron.runNowResult : nil
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Select an entry, or click Add to create one.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Single row

private struct CronEntryRow: View {
    let entry: CronEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.schedule.summary)
                .font(.body)
                .lineLimit(1)
            Text(entry.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let comment = entry.comment, !comment.isEmpty {
                Text("# \(comment)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - History pane

private struct CronHistoryPane: View {
    @Bindable var session: SessionState

    var body: some View {
        switch session.cron.historyStatus {
        case .idle, .loading:
            ProgressView("Reading mail spool…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 36))
                    .foregroundStyle(.red.opacity(0.6))
                Text("Couldn't read history")
                    .font(.headline)
                Text(msg).font(.caption).foregroundStyle(.secondary)
                Button("Retry") { Task { await session.loadCronHistory() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if session.cron.history.isEmpty {
                emptyStateWithDiagnostics
            } else {
                VStack(spacing: 0) {
                    if !session.cron.historyDiagnostics.isEmpty {
                        diagnosticsBanner
                    }
                    List(session.cron.history) { record in
                    DisclosureGroup {
                        Text(record.output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.command)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(record.preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let ts = record.timestamp {
                                Text(ts, format: .relative(presentation: .named))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    private var diagnosticsBanner: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.cron.historyDiagnostics) { diag in
                    diagnosticRow(diag)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                Text("Diagnostics (\(session.cron.historyDiagnostics.count))")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.secondary.opacity(0.06))
    }

    private var emptyStateWithDiagnostics: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No run history found")
                    .font(.headline)
                Text("Cron writes to the mail spool only when a job produces output AND `MAILTO` is set AND a working MTA is installed. Most macOS systems don't have one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !session.cron.historyDiagnostics.isEmpty {
                Divider().padding(.horizontal, 32)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What we checked")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(session.cron.historyDiagnostics) { diag in
                            diagnosticRow(diag)
                        }
                        suggestionPane
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 600)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func diagnosticRow(_ diag: CronDiagnostic) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: diag.severity.systemImage)
                .foregroundStyle(diagColor(diag.severity))
                .font(.caption)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(diag.title)
                    .font(.caption.bold())
                Text(diag.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func diagColor(_ severity: CronDiagnostic.Severity) -> Color {
        switch severity {
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }

    private var suggestionPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Want to capture output anyway?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("Append `>> /tmp/cron-mycommand.log 2>&1` to your command, then `cat /tmp/cron-mycommand.log` from the Files surface to see what the job wrote. A built-in capture-to-file toggle is on the roadmap.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }
}
