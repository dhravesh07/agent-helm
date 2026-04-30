import Foundation

struct CronDiagnostic: Identifiable, Hashable {
    enum Severity: Hashable {
        case info, warn, error
        var systemImage: String {
            switch self {
            case .info: return "info.circle"
            case .warn: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            }
        }
    }

    let id: UUID = UUID()
    let severity: Severity
    let title: String
    let detail: String
}

struct CronHistoryResult: Equatable {
    var records: [CronRunRecord]
    var diagnostics: [CronDiagnostic]
}
