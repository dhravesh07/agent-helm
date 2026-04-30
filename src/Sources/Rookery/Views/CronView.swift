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
                    Text("• Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                saveStatusLabel
                Button("Reload") {
                    Task { await session.loadCron() }
                }
                Button {
                    Task { await session.saveCron() }
                } label: {
                    Label("Install crontab", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!session.cron.dirty || session.cron.saveStatus == .saving)
            case .history:
                Button {
                    Task { await session.loadCronHistory() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No run history found in /var/mail/$USER")
                        .foregroundStyle(.secondary)
                    Text("Cron only writes to the mail spool when a job produces stdout/stderr.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
