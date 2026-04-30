import Foundation

enum CronParser {
    /// Parse a `crontab -l` output into entries plus a list of preserved
    /// preamble lines (e.g., environment variables `PATH=...`, plain
    /// comments) that we round-trip unchanged.
    static func parse(_ text: String) -> (preamble: [String], entries: [CronEntry]) {
        var preamble: [String] = []
        var entries: [CronEntry] = []
        var pendingComment: String?

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if entries.isEmpty {
                    preamble.append(line)
                }
                pendingComment = nil
                continue
            }

            if trimmed.hasPrefix("#") {
                if entries.isEmpty {
                    preamble.append(line)
                } else {
                    pendingComment = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            // Environment variable like FOO=bar — leave in preamble until the
            // first cron entry is seen.
            if entries.isEmpty, trimmed.range(of: #"^[A-Z_][A-Z0-9_]*\s*="#, options: .regularExpression) != nil {
                preamble.append(line)
                continue
            }

            if let entry = parseEntry(line, comment: pendingComment) {
                entries.append(entry)
            } else {
                // Unrecognized but non-empty: keep as raw entry to avoid losing it.
                entries.append(
                    CronEntry(
                        schedule: .raw(""),
                        command: line,
                        comment: pendingComment,
                        rawLine: line
                    )
                )
            }
            pendingComment = nil
        }
        return (preamble, entries)
    }

    /// Serialize entries back to a crontab string. Preamble is emitted
    /// first, then a blank line if there were entries, then the entries.
    static func serialize(preamble: [String], entries: [CronEntry]) -> String {
        var out: [String] = preamble
        if !preamble.isEmpty, !entries.isEmpty, preamble.last?.isEmpty == false {
            out.append("")
        }
        for entry in entries {
            if let comment = entry.comment, !comment.isEmpty {
                out.append("# \(comment)")
            }
            out.append("\(entry.schedule.expression) \(entry.command)")
        }
        // Crontab files traditionally end with a newline.
        if let last = out.last, !last.isEmpty {
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    /// Parse a single entry line. Returns nil if it doesn't look like a
    /// cron entry at all.
    static func parseEntry(_ line: String, comment: String? = nil) -> CronEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // @shorthand commands: @daily /usr/bin/foo
        if trimmed.hasPrefix("@") {
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 1 else { return nil }
            let shorthand = String(parts[0])
            guard CronSchedule.allShorthands.contains(shorthand) else { return nil }
            let cmd = parts.count == 2 ? String(parts[1]) : ""
            return CronEntry(
                schedule: .shorthand(shorthand),
                command: cmd,
                comment: comment,
                rawLine: line
            )
        }

        // 5 fields then command.
        let scanner = Scanner(string: trimmed)
        scanner.charactersToBeSkipped = nil
        let whitespace = CharacterSet.whitespaces

        var fields: [String] = []
        for _ in 0..<5 {
            _ = scanner.scanCharacters(from: whitespace)
            guard let field = scanner.scanUpToCharacters(from: whitespace) else { return nil }
            fields.append(field)
        }
        _ = scanner.scanCharacters(from: whitespace)
        let remainder = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: trimmed))...])
        let command = remainder.trimmingCharacters(in: .whitespaces)

        guard !command.isEmpty else { return nil }
        guard fields.allSatisfy({ isPlausibleField($0) }) else { return nil }

        return CronEntry(
            schedule: .standard(
                minute: fields[0],
                hour: fields[1],
                dom: fields[2],
                month: fields[3],
                dow: fields[4]
            ),
            command: command,
            comment: comment,
            rawLine: line
        )
    }

    /// Loose plausibility check on a single field. We trust crontab itself
    /// to do the strict validation when we save.
    static func isPlausibleField(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789*,-/")
        // also allow short day/month names (JAN, MON, etc.)
        let alphaAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        let combined = allowed.union(alphaAllowed)
        return s.unicodeScalars.allSatisfy { combined.contains($0) }
    }
}
