import Foundation

/// A single cron entry parsed from a crontab line. The `id` is stable
/// only within the in-memory list — it doesn't survive round-trips to
/// disk; we match by `rawLine` if we need to identify a specific entry
/// after a reload.
struct CronEntry: Identifiable, Hashable {
    let id: UUID
    var schedule: CronSchedule
    var command: String
    var comment: String?
    var rawLine: String

    init(
        id: UUID = UUID(),
        schedule: CronSchedule,
        command: String,
        comment: String? = nil,
        rawLine: String? = nil
    ) {
        self.id = id
        self.schedule = schedule
        self.command = command
        self.comment = comment
        self.rawLine = rawLine ?? "\(schedule.expression) \(command)"
    }
}

enum CronSchedule: Equatable, Hashable {
    case standard(minute: String, hour: String, dom: String, month: String, dow: String)
    case shorthand(String)
    case raw(String)

    static let allShorthands = ["@reboot", "@yearly", "@annually", "@monthly", "@weekly", "@daily", "@midnight", "@hourly"]

    var expression: String {
        switch self {
        case let .standard(m, h, d, mo, w):
            return "\(m) \(h) \(d) \(mo) \(w)"
        case .shorthand(let s):
            return s
        case .raw(let s):
            return s
        }
    }

    /// Human-readable summary like "Every day at 09:30" or "Every 5 minutes".
    /// Falls back to the raw expression if it doesn't match a known pattern.
    var summary: String {
        switch self {
        case .shorthand(let s):
            switch s {
            case "@reboot":   return "At boot"
            case "@hourly":   return "Every hour"
            case "@daily", "@midnight": return "Every day at midnight"
            case "@weekly":   return "Every week (Sunday midnight)"
            case "@monthly":  return "Every month (1st at midnight)"
            case "@yearly", "@annually": return "Every year (Jan 1 midnight)"
            default: return s
            }
        case .raw(let s):
            return s
        case let .standard(m, h, d, mo, w):
            // Quick-pattern detection.
            if m == "*" && h == "*" && d == "*" && mo == "*" && w == "*" {
                return "Every minute"
            }
            if m.hasPrefix("*/"), h == "*", d == "*", mo == "*", w == "*" {
                return "Every \(m.dropFirst(2)) minutes"
            }
            if m == "0" && h == "*" && d == "*" && mo == "*" && w == "*" {
                return "Every hour, on the hour"
            }
            if let mInt = Int(m), let hInt = Int(h),
               d == "*", mo == "*", w == "*" {
                return String(format: "Every day at %02d:%02d", hInt, mInt)
            }
            if let mInt = Int(m), let hInt = Int(h), let wInt = Int(w),
               d == "*", mo == "*" {
                return String(format: "Every week on %@ at %02d:%02d", Self.dayName(wInt), hInt, mInt)
            }
            if let mInt = Int(m), let hInt = Int(h), let dInt = Int(d),
               mo == "*", w == "*" {
                let suffix = Self.daySuffix(dInt)
                return String(format: "Every month on the %d%@ at %02d:%02d", dInt, suffix, hInt, mInt)
            }
            return "\(m) \(h) \(d) \(mo) \(w)"
        }
    }

    private static func dayName(_ d: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][min(max(d, 0), 7)]
    }

    private static func daySuffix(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 13 { return "th" }
        switch mod10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
