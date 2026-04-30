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

    /// Read run history with diagnostic probes. Falls back to macOS
    /// unified-log on local hosts when the mail spool is empty.
    func readRunHistory(hostKind: HostKind) async throws -> CronHistoryResult {
        var diagnostics: [CronDiagnostic] = []

        // Probe 1 — mail spool path + size
        let spoolInfo = (try? await service.runShellCommand(
            #"for f in "/var/mail/$(whoami)" "/var/spool/mail/$(whoami)"; do if [ -e "$f" ]; then echo "$f|present|$(wc -c < "$f" 2>/dev/null | tr -d ' ')"; else echo "$f|missing|"; fi; done"#
        )) ?? ""
        let spoolLines = spoolInfo.components(separatedBy: "\n").filter { !$0.isEmpty }
        var spoolHasContent = false
        for line in spoolLines {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            let path = parts[0], state = parts[1], bytes = parts[2]
            switch state {
            case "missing":
                diagnostics.append(.init(
                    severity: .info,
                    title: "Mail spool absent",
                    detail: "\(path) does not exist. cron sends output here only when MAILTO and an MTA are configured."
                ))
            case "present":
                let size = Int(bytes) ?? 0
                if size > 0 {
                    spoolHasContent = true
                    diagnostics.append(.init(
                        severity: .info,
                        title: "Mail spool present",
                        detail: "\(path) — \(size) bytes."
                    ))
                } else {
                    diagnostics.append(.init(
                        severity: .info,
                        title: "Mail spool empty",
                        detail: "\(path) exists but is 0 bytes."
                    ))
                }
            default: break
            }
        }

        // Probe 2 — MAILTO setting in user's crontab
        let mailto = ((try? await service.runShellCommand(
            "crontab -l 2>/dev/null | grep -E '^MAILTO' | head -1 || true"
        )) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if mailto.isEmpty {
            diagnostics.append(.init(
                severity: .warn,
                title: "MAILTO is not set",
                detail: "Without MAILTO and a working MTA (sendmail / postfix), cron drops command output silently. Most macOS systems do not have an MTA configured by default."
            ))
        } else {
            diagnostics.append(.init(
                severity: .info,
                title: "MAILTO configured",
                detail: mailto
            ))
        }

        // Probe 3 — cron daemon presence
        let cronProc = ((try? await service.runShellCommand(
            "pgrep -l cron 2>/dev/null; pgrep -l crond 2>/dev/null; true"
        )) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if cronProc.isEmpty {
            diagnostics.append(.init(
                severity: .warn,
                title: "No cron/crond process detected",
                detail: "pgrep didn't find a running cron daemon. On macOS, cron is enabled but lives behind launchd; jobs may still run via the cron compatibility shim."
            ))
        } else {
            diagnostics.append(.init(
                severity: .info,
                title: "cron daemon running",
                detail: cronProc
            ))
        }

        // Probe 4 — parse mail spool (always)
        let mailRaw = try await service.runShellCommand(
            "cat \"/var/mail/$(whoami)\" 2>/dev/null || cat \"/var/spool/mail/$(whoami)\" 2>/dev/null || true"
        )
        var records = CronHistoryParser.parse(mailRaw)
        _ = spoolHasContent  // intentional: signal already encoded in diagnostics + record count

        // Probe 5 — macOS unified-log fallback for local hosts
        if records.isEmpty, hostKind == .local {
            let logRaw = ((try? await service.runShellCommand(
                #"log show --predicate 'process == "cron"' --info --style compact --last 1d 2>/dev/null | tail -200 || true"#
            )) ?? "")
            let unified = CronHistoryParser.parseUnifiedLog(logRaw)
            if !unified.isEmpty {
                records = unified
                diagnostics.append(.init(
                    severity: .info,
                    title: "Using macOS unified log as fallback",
                    detail: "Recovered \(unified.count) run\(unified.count == 1 ? "" : "s") from `log show --predicate 'process == \"cron\"'`. Output isn't captured this way — only timestamps and commands."
                ))
            } else {
                diagnostics.append(.init(
                    severity: .info,
                    title: "Unified log returned no cron events",
                    detail: "macOS `log show` has no cron entries in the last 24h. The job may not have fired yet, or `log show` requires elevated privileges to read cron events on this system."
                ))
            }
        }

        return CronHistoryResult(records: records, diagnostics: diagnostics)
    }

    private static func shellQuote(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
