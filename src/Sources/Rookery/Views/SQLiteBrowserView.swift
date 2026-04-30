import SwiftUI

/// Three-mode SQLite inspector. Owns its own `SQLiteService` (read-only); the
/// outer FileEditorView passes in the local file URL plus the chosen view
/// mode. State here is per-DB-open; a different file kicks a fresh view.
struct SQLiteBrowserView: View {
    let localPath: URL
    let mode: FileViewMode

    @State private var service = SQLiteService()
    @State private var tables: [SQLiteTable] = []
    @State private var loadError: String?
    @State private var isLoadingTables = true
    @State private var selectedTableId: String?
    @State private var columns: [SQLiteColumn] = []
    @State private var rowCount: Int = 0
    @State private var rows: SQLiteResultSet = .empty
    @State private var page: Int = 0
    @State private var queryText: String = "SELECT name FROM sqlite_master WHERE type='table';"
    @State private var queryResult: SQLiteResultSet = .empty
    @State private var queryError: String?
    @State private var isRunningQuery = false

    private static let pageSize = 50

    var body: some View {
        Group {
            if let loadError {
                errorPane(loadError)
            } else if isLoadingTables {
                ProgressView("Opening database…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch mode {
                case .tables: tablesMode
                case .schema: schemaMode
                case .query:  queryMode
                default:      tablesMode
                }
            }
        }
        .task(id: localPath) {
            await openDatabase()
        }
        .task(id: selectedTableId) {
            await loadSelectedTable()
        }
    }

    // MARK: - Tables mode

    private var tablesMode: some View {
        HSplitView {
            tableSidebar
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
            tableContent
                .frame(minWidth: 360)
        }
    }

    private var tableSidebar: some View {
        List(tables, selection: $selectedTableId) { table in
            HStack {
                Image(systemName: table.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(table.name)
                        .font(.system(.body, design: .monospaced))
                    if let count = table.rowCount {
                        Text("\(count) row\(count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .tag(table.id)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var tableContent: some View {
        if let id = selectedTableId, !id.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                tableMetadataBar(name: id)
                Divider()
                rowsTable
                Divider()
                paginationBar
            }
        } else {
            placeholder("Select a table", systemImage: "tablecells")
        }
    }

    private func tableMetadataBar(name: String) -> some View {
        HStack(spacing: 16) {
            Text(name)
                .font(.system(.title3, design: .monospaced))
            Text("\(rowCount) row\(rowCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(columns.count) column\(columns.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await loadSelectedTable() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var rowsTable: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(rows.columns, id: \.self) { col in
                        Text(col)
                            .font(.system(.caption, design: .monospaced).bold())
                            .frame(minWidth: 120, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
                Divider()
                // Rows
                ForEach(rows.rows) { row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                    }
                    .background(row.id.isMultiple(of: 2) ? Color.clear : Color(nsColor: .alternatingContentBackgroundColors[1]))
                }
                if rows.rows.isEmpty {
                    Text("(no rows)")
                        .foregroundStyle(.tertiary)
                        .padding()
                }
            }
        }
    }

    private var paginationBar: some View {
        HStack {
            Button {
                if page > 0 {
                    page -= 1
                    Task { await loadPage() }
                }
            } label: { Image(systemName: "chevron.left") }
            .disabled(page == 0)

            Text("Page \(page + 1) of \(max(1, (rowCount + Self.pageSize - 1) / Self.pageSize))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                let totalPages = (rowCount + Self.pageSize - 1) / Self.pageSize
                if page < totalPages - 1 {
                    page += 1
                    Task { await loadPage() }
                }
            } label: { Image(systemName: "chevron.right") }
            .disabled(page >= (rowCount + Self.pageSize - 1) / Self.pageSize - 1)

            Spacer()

            if rows.truncated {
                Text("Truncated to \(Self.pageSize) rows per page")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .buttonStyle(.borderless)
    }

    // MARK: - Schema mode

    private var schemaMode: some View {
        HSplitView {
            tableSidebar
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
            schemaContent
                .frame(minWidth: 360)
        }
    }

    @ViewBuilder
    private var schemaContent: some View {
        if let id = selectedTableId,
           let table = tables.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: table.systemImage)
                        Text(table.name)
                            .font(.title2.monospaced())
                        Spacer()
                    }
                    columnsTable
                    if let sql = table.createSQL, !sql.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CREATE statement")
                                .font(.headline)
                            Text(sql)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(20)
            }
        } else {
            placeholder("Select a table", systemImage: "list.bullet.rectangle")
        }
    }

    private var columnsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Columns")
                .font(.headline)
                .padding(.bottom, 6)
            HStack(spacing: 0) {
                Text("Name")
                    .font(.caption.bold())
                    .frame(width: 180, alignment: .leading)
                Text("Type")
                    .font(.caption.bold())
                    .frame(width: 140, alignment: .leading)
                Text("Constraints")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            Divider()
            ForEach(columns) { col in
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if col.primaryKey {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                                .font(.caption2)
                        }
                        Text(col.name)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .frame(width: 180, alignment: .leading)
                    Text(col.type.isEmpty ? "—" : col.type)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                    Text(constraintsString(col))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func constraintsString(_ col: SQLiteColumn) -> String {
        var parts: [String] = []
        if col.notNull { parts.append("NOT NULL") }
        if col.primaryKey { parts.append("PRIMARY KEY") }
        if let def = col.defaultValue { parts.append("DEFAULT \(def)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Query mode

    private var queryMode: some View {
        VSplitView {
            queryEditor
                .frame(minHeight: 120, idealHeight: 160)
            queryResults
                .frame(minHeight: 160)
        }
    }

    private var queryEditor: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Read-only query (SELECT / WITH / PRAGMA / EXPLAIN)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isRunningQuery {
                    ProgressView().controlSize(.small)
                }
                Button {
                    runQuery()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isRunningQuery)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            LineNumberedTextEditor(
                text: $queryText,
                isMonospaced: true,
                languageSpec: SyntaxLanguages.spec(forExtension: "sql")
            )
        }
    }

    @ViewBuilder
    private var queryResults: some View {
        if let queryError {
            errorPane(queryError)
        } else if queryResult.columns.isEmpty {
            placeholder("Run a query to see results", systemImage: "terminal")
        } else {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(queryResult.columns, id: \.self) { col in
                            Text(col)
                                .font(.system(.caption, design: .monospaced).bold())
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .windowBackgroundColor))
                        }
                    }
                    Divider()
                    ForEach(queryResult.rows) { row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(3)
                                    .truncationMode(.tail)
                                    .frame(minWidth: 120, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    if queryResult.truncated {
                        Text("Result truncated to 1000 rows.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func placeholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorPane(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon")
                .font(.system(size: 36))
                .foregroundStyle(.red.opacity(0.6))
            Text(msg)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Async actions

    private func openDatabase() async {
        isLoadingTables = true
        loadError = nil
        do {
            try await service.open(at: localPath.path)
            let fetched = try await service.listTables()
            self.tables = fetched
            self.selectedTableId = fetched.first?.id
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingTables = false
    }

    private func loadSelectedTable() async {
        guard let id = selectedTableId, !id.isEmpty else {
            columns = []
            rows = .empty
            rowCount = 0
            return
        }
        do {
            async let cols = service.columns(of: id)
            async let count = service.rowCount(of: id)
            self.columns = try await cols
            self.rowCount = try await count
            self.page = 0
            await loadPage()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadPage() async {
        guard let id = selectedTableId else { return }
        do {
            let result = try await service.fetchRows(
                table: id,
                limit: Self.pageSize,
                offset: page * Self.pageSize
            )
            self.rows = result
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func runQuery() {
        Task {
            isRunningQuery = true
            queryError = nil
            do {
                let result = try await service.runReadOnlyQuery(queryText)
                self.queryResult = result
            } catch {
                queryError = error.localizedDescription
                queryResult = .empty
            }
            isRunningQuery = false
        }
    }
}
