import Foundation
import Observation

enum HostSurface: String, CaseIterable, Identifiable {
    case files
    case cron

    var id: String { rawValue }

    var label: String {
        switch self {
        case .files: return "Files"
        case .cron:  return "Cron"
        }
    }

    var systemImage: String {
        switch self {
        case .files: return "folder"
        case .cron:  return "clock"
        }
    }
}

enum CronTab: String, CaseIterable, Identifiable {
    case entries
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .entries: return "Entries"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .entries: return "list.bullet"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

enum CronLoadStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@Observable
@MainActor
final class CronState {
    var tab: CronTab = .entries

    // Entries
    var preamble: [String] = []
    var entries: [CronEntry] = []
    var selectedEntryId: CronEntry.ID?
    var status: CronLoadStatus = .idle
    var saveStatus: SaveStatus = .idle
    var validationProblems: [String] = []
    var dirty: Bool = false

    // Run-now
    var runNowResult: String?
    var runNowEntryId: CronEntry.ID?

    // History
    var history: [CronRunRecord] = []
    var historyStatus: CronLoadStatus = .idle
    var historyDiagnostics: [CronDiagnostic] = []

    func reset() {
        tab = .entries
        preamble = []
        entries = []
        selectedEntryId = nil
        status = .idle
        saveStatus = .idle
        validationProblems = []
        dirty = false
        runNowResult = nil
        runNowEntryId = nil
        history = []
        historyStatus = .idle
        historyDiagnostics = []
    }
}
