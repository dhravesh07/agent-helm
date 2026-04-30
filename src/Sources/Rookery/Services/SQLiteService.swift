import Foundation
import GRDB

/// Read-only SQLite service. Wraps a `DatabaseQueue` opened with
/// `Configuration.readonly = true`. The query runner refuses anything that
/// isn't a SELECT, PRAGMA, or EXPLAIN — we don't write to agent state.
actor SQLiteService {
    private var queue: DatabaseQueue?
    private(set) var path: String?

    func open(at path: String) async throws {
        await close()

        var config = Configuration()
        config.readonly = true
        do {
            self.queue = try DatabaseQueue(path: path, configuration: config)
            self.path = path
        } catch {
            throw SQLiteQueryError.grdb(underlying: error.localizedDescription)
        }
    }

    func close() async {
        // GRDB's DatabaseQueue closes on deinit. Just drop the reference.
        self.queue = nil
        self.path = nil
    }

    // MARK: - Schema

    func listTables() async throws -> [SQLiteTable] {
        guard let queue else { throw SQLiteQueryError.databaseUnavailable }
        do {
            return try await queue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT name, type, sql
                      FROM sqlite_master
                     WHERE type IN ('table', 'view')
                       AND name NOT LIKE 'sqlite_%'
                  ORDER BY type, name
                """)
                return rows.compactMap { row -> SQLiteTable? in
                    let name: String = row["name"] ?? ""
                    let typeStr: String = row["type"] ?? "table"
                    let sql: String? = row["sql"]
                    guard !name.isEmpty else { return nil }
                    let kind: SQLiteTable.TableKind
                    switch typeStr {
                    case "view":    kind = .view
                    case "table":   kind = .table
                    default:        kind = .table
                    }
                    return SQLiteTable(id: name, name: name, kind: kind, createSQL: sql, rowCount: nil)
                }
            }
        } catch let err as SQLiteQueryError {
            throw err
        } catch {
            throw SQLiteQueryError.grdb(underlying: error.localizedDescription)
        }
    }

    func columns(of tableName: String) async throws -> [SQLiteColumn] {
        guard let queue else { throw SQLiteQueryError.databaseUnavailable }
        do {
            return try await queue.read { db in
                let escaped = tableName.replacingOccurrences(of: "\"", with: "\"\"")
                let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(\"\(escaped)\")")
                return rows.map { row in
                    SQLiteColumn(
                        id: "\(tableName).\(row["name"] ?? "")",
                        name: row["name"] ?? "",
                        type: row["type"] ?? "",
                        notNull: (row["notnull"] as Int? ?? 0) != 0,
                        primaryKey: (row["pk"] as Int? ?? 0) != 0,
                        defaultValue: row["dflt_value"]
                    )
                }
            }
        } catch {
            throw SQLiteQueryError.grdb(underlying: error.localizedDescription)
        }
    }

    func rowCount(of tableName: String) async throws -> Int {
        guard let queue else { throw SQLiteQueryError.databaseUnavailable }
        let escaped = tableName.replacingOccurrences(of: "\"", with: "\"\"")
        do {
            return try await queue.read { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \"\(escaped)\"") ?? 0
                return count
            }
        } catch {
            throw SQLiteQueryError.grdb(underlying: error.localizedDescription)
        }
    }

    // MARK: - Row fetching

    func fetchRows(table: String, limit: Int, offset: Int) async throws -> SQLiteResultSet {
        let escaped = table.replacingOccurrences(of: "\"", with: "\"\"")
        return try await runSelect(sql: "SELECT * FROM \"\(escaped)\" LIMIT \(limit) OFFSET \(offset)")
    }

    /// Run a user-supplied query. Refuses non-read statements at the syntax
    /// level — read-only mode at the connection level is the actual guarantee,
    /// but this gives a friendlier error.
    func runReadOnlyQuery(_ sql: String, limit: Int = 1000) async throws -> SQLiteResultSet {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let upper = trimmed.uppercased()
        let allowedPrefixes = ["SELECT", "WITH", "PRAGMA", "EXPLAIN"]
        let firstWord = upper.split(separator: " ").first.map(String.init) ?? ""
        guard allowedPrefixes.contains(firstWord) else {
            throw SQLiteQueryError.unsupportedStatement(
                message: "Only SELECT, WITH, PRAGMA, and EXPLAIN are allowed in the query runner."
            )
        }
        return try await runSelect(sql: trimmed, limit: limit)
    }

    private func runSelect(sql: String, limit: Int = 1000) async throws -> SQLiteResultSet {
        guard let queue else { throw SQLiteQueryError.databaseUnavailable }
        do {
            return try await queue.read { db in
                let rows = try Row.fetchAll(db, sql: sql)
                guard let first = rows.first else {
                    // Empty result. Try to get column names from a prepared statement.
                    let stmt = try db.makeStatement(sql: sql)
                    return SQLiteResultSet(columns: Array(stmt.columnNames), rows: [], truncated: false)
                }
                let columns = Array(first.columnNames)
                let truncated = rows.count > limit
                let limited = Array(rows.prefix(limit))
                let resultRows: [SQLiteRow] = limited.enumerated().map { idx, row in
                    let cells: [String] = (0..<row.count).map { Self.stringify(row[$0]) }
                    return SQLiteRow(id: idx, cells: cells)
                }
                return SQLiteResultSet(columns: columns, rows: resultRows, truncated: truncated)
            }
        } catch let err as SQLiteQueryError {
            throw err
        } catch {
            throw SQLiteQueryError.grdb(underlying: error.localizedDescription)
        }
    }

    private static func stringify(_ value: DatabaseValue) -> String {
        switch value.storage {
        case .null:           return "NULL"
        case .int64(let i):   return String(i)
        case .double(let d):  return String(d)
        case .string(let s):  return s
        case .blob(let data): return "<blob \(data.count) bytes>"
        }
    }
}
