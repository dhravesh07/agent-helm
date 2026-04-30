import Foundation

/// One row of `PRAGMA table_info("table")`.
struct SQLiteColumn: Identifiable, Hashable {
    let id: String        // table.name
    let name: String
    let type: String
    let notNull: Bool
    let primaryKey: Bool
    let defaultValue: String?
}

struct SQLiteTable: Identifiable, Hashable {
    let id: String        // table name
    let name: String
    let kind: TableKind
    let createSQL: String?
    var rowCount: Int?

    enum TableKind: String, Hashable {
        case table
        case view
        case virtual
        case shadow
    }

    var systemImage: String {
        switch kind {
        case .table:   return "tablecells"
        case .view:    return "list.dash"
        case .virtual: return "tablecells.badge.ellipsis"
        case .shadow:  return "circle.dotted"
        }
    }
}

/// One row of result data, in column order. Values are stringified for display.
struct SQLiteRow: Identifiable, Hashable {
    let id: Int
    let cells: [String]
}

struct SQLiteResultSet: Equatable {
    let columns: [String]
    let rows: [SQLiteRow]
    let truncated: Bool

    static let empty = SQLiteResultSet(columns: [], rows: [], truncated: false)
}

enum SQLiteQueryError: LocalizedError {
    case databaseUnavailable
    case readOnly(message: String)
    case unsupportedStatement(message: String)
    case grdb(underlying: String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Database is not open."
        case .readOnly(let m):
            return "Read-only mode: \(m)"
        case .unsupportedStatement(let m):
            return m
        case .grdb(let m):
            return "Database error: \(m)"
        }
    }
}
