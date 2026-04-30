import Foundation

enum CronServiceError: LocalizedError {
    case notConnected
    case crontabUnavailable(stderr: String)
    case writeFailed(stderr: String)
    case runFailed(stderr: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected."
        case .crontabUnavailable(let s):
            return "crontab is unavailable: \(s)"
        case .writeFailed(let s):
            return "Failed to install new crontab: \(s)"
        case .runFailed(let s):
            return "Run failed: \(s)"
        }
    }
}

/// Stateless façade over a `RemoteFileService`. Handles the standard cron
/// operations: list, save, trigger run-now, and read the user's mail spool
/// for run history.
struct CronService: Sendable {
    let service: any RemoteFileService

    /// `crontab -l` and parse.
    func listEntries() async throws -> (preamble: [String], entries: [CronEntry]) {
        do {
            let raw = try await service.runShellCommand("crontab -l 2>/dev/null || true")
            return CronParser.parse(raw)
        } catch {
            throw CronServiceError.crontabUnavailable(stderr: error.localizedDescription)
        }
    }

    /// Save new crontab. Writes to a tmp file via the service's file API,
    /// then runs `crontab <tmpfile>`. Cleans up after.
    func save(preamble: [String], entries: [CronEntry]) async throws {
        let serialized = CronParser.serialize(preamble: preamble, entries: entries)
        let data = Data(serialized.utf8)

        // Random tmp path; /tmp is universally writable and the crontab
        // command happily reads it.
        let tmpPath = "/tmp/rookery-crontab-\(UUID().uuidString).cron"
        try await service.writeFile(at: tmpPath, contents: data)
        do {
            _ = try await service.runShellCommand(
                "crontab \(Self.shellQuote(tmpPath)) && rm -f \(Self.shellQuote(tmpPath))"
            )
        } catch {
            // Best-effort cleanup of the tmp file even on failure.
            _ = try? await service.runShellCommand("rm -f \(Self.shellQuote(tmpPath))")
            throw CronServiceError.writeFailed(stderr: error.localizedDescription)
        }
    }

    /// Validate by writing the proposed crontab to a tmp file and running
    /// the platform's `crontab -T` (BSD/macOS) or invoking
    /// `crontab <file>` against an isolated user wouldn't work portably —
    /// so we settle for parsing locally and surface obvious issues.
    /// Strict server-side validation happens at save time.
    static func validate(_ entries: [CronEntry]) -> [String] {
        var problems: [String] = []
        for (i, entry) in entries.enumerated() {
            if entry.command.trimmingCharacters(in: .whitespaces).isEmpty {
                problems.append("Entry \(i + 1): command is empty.")
            }
            switch entry.schedule {
            case .standard(let m, let h, let d, let mo, let w):
                for (idx, field) in [m, h, d, mo, w].enumerated() {
                    if !CronParser.isPlausibleField(field) {
                        problems.append("Entry \(i + 1) field \(idx + 1) ('\(field)') has unexpected characters.")
                    }
                }
            case .shorthand(let s):
                if !CronSchedule.allShorthands.contains(s) {
                    problems.append("Entry \(i + 1): unknown shorthand '\(s)'.")
                }
            case .raw(let s):
                if s.isEmpty {
                    problems.append("Entry \(i + 1): schedule expression is empty.")
                }
            }
        }
        return problems
    }

    /// Trigger one-shot run of an entry's command. Captures combined
    /// stdout/stderr.
    func runNow(_ entry: CronEntry) async throws -> String {
        do {
            let result = try await service.runShellCommand(
                "{ \(entry.command) ; } 2>&1"
            )
            return result
        } catch {
            throw CronServiceError.runFailed(stderr: error.localizedDescription)
        }
    }

    /// Read and parse the user's mail spool for cron's run history.
    /// Falls back to empty if the spool doesn't exist or isn't readable.
    func readRunHistory() async throws -> [CronRunRecord] {
        let raw = try await service.runShellCommand(
            "cat \"/var/mail/$(whoami)\" 2>/dev/null || cat \"/var/spool/mail/$(whoami)\" 2>/dev/null || true"
        )
        return CronHistoryParser.parse(raw)
    }

    private static func shellQuote(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
