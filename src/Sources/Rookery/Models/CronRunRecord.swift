import Foundation

/// A single past run of a cron entry, parsed from the user's mail spool
/// (`/var/mail/$USER`). Cron sends one mail message per run that produced
/// stdout/stderr; messages with no output are silent.
struct CronRunRecord: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date?
    let command: String
    let output: String

    /// Best-effort summary — first non-empty output line.
    var preview: String {
        let firstLine = output
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? "(no output)"
        return firstLine
    }
}

enum CronHistoryParser {
    /// Parse macOS unified-log output for cron process events. The
    /// `log show --predicate 'process == "cron"' --style compact` format
    /// has lines like:
    ///   2026-04-30 17:35:00.123456 0xae28b   I  Default cron: (user) CMD (echo hello)
    /// We extract the timestamp and the CMD payload.
    static func parseUnifiedLog(_ raw: String) -> [CronRunRecord] {
        var records: [CronRunRecord] = []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Find "CMD (...)" payload — only those lines are runs.
            guard let cmdRange = trimmed.range(of: "CMD (") else { continue }
            let after = trimmed[cmdRange.upperBound...]
            guard let endParen = after.range(of: ")", options: .backwards) else { continue }
            let command = String(after[after.startIndex..<endParen.lowerBound])
                .trimmingCharacters(in: .whitespaces)

            // Timestamp: first 19 chars of "2026-04-30 17:35:00".
            let ts: Date? = {
                guard trimmed.count >= 19 else { return nil }
                let stamp = String(trimmed.prefix(19))
                return formatter.date(from: stamp)
            }()

            records.append(CronRunRecord(
                id: UUID(),
                timestamp: ts,
                command: command,
                output: "(no captured output — recovered from macOS unified log; cron only mails when MAILTO is set)"
            ))
        }
        return records.sorted { (lhs, rhs) -> Bool in
            switch (lhs.timestamp, rhs.timestamp) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return false
            }
        }
    }

    /// Parse a Unix mail spool. Each message starts with a `From ` line.
    /// Cron's messages have a `Subject: Cron <user@host> <command>` header.
    static func parse(_ raw: String) -> [CronRunRecord] {
        guard !raw.isEmpty else { return [] }
        var records: [CronRunRecord] = []

        // Split on lines that start with "From " (the mbox separator).
        let lines = raw.components(separatedBy: "\n")
        var current: [String] = []
        var allMessages: [[String]] = []
        for line in lines {
            if line.hasPrefix("From ") {
                if !current.isEmpty {
                    allMessages.append(current)
                }
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            allMessages.append(current)
        }

        for message in allMessages {
            guard let record = parseMessage(message) else { continue }
            if record.command.lowercased().contains("cron") || record.timestamp != nil {
                records.append(record)
            } else {
                records.append(record)
            }
        }

        // Newest first.
        return records.sorted { (lhs, rhs) -> Bool in
            switch (lhs.timestamp, rhs.timestamp) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return false
            }
        }
    }

    private static func parseMessage(_ lines: [String]) -> CronRunRecord? {
        var subject: String?
        var dateString: String?
        var bodyStart = 0
        // Headers end at the first blank line.
        for (i, line) in lines.enumerated() {
            if line.isEmpty {
                bodyStart = i + 1
                break
            }
            if line.lowercased().hasPrefix("subject:") {
                subject = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("date:") {
                dateString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }

        let body = lines[bodyStart..<lines.count].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Subject "Cron <user@host> <command>" → strip the "Cron <user@host>" prefix.
        let command: String = {
            guard let s = subject else { return "(unknown)" }
            if s.hasPrefix("Cron ") {
                if let lt = s.firstIndex(of: ">") {
                    let after = s.index(after: lt)
                    return String(s[after...]).trimmingCharacters(in: .whitespaces)
                }
                return String(s.dropFirst(5))
            }
            return s
        }()

        return CronRunRecord(
            id: UUID(),
            timestamp: dateString.flatMap { Self.parseRFC2822($0) },
            command: command,
            output: body
        )
    }

    private static func parseRFC2822(_ s: String) -> Date? {
        // Headers use RFC 2822: "Mon, 21 Apr 2026 14:30:00 +0000"
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        if let d = f.date(from: s) { return d }
        // Some senders skip the day-of-week.
        f.dateFormat = "d MMM yyyy HH:mm:ss Z"
        return f.date(from: s)
    }
}
