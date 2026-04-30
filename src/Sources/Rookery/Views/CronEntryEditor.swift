import SwiftUI

struct CronEntryEditor: View {
    let entry: CronEntry
    let onChange: (CronEntry) -> Void
    let onRunNow: (CronEntry) -> Void
    let runNowResult: String?

    enum Mode: String, CaseIterable, Identifiable {
        case quick
        case custom
        case raw
        var id: String { rawValue }
        var label: String {
            switch self {
            case .quick: return "Quick"
            case .custom: return "Custom (5 fields)"
            case .raw: return "Raw expression"
            }
        }
    }

    @State private var mode: Mode = .quick
    @State private var quickKind: QuickKind = .everyDay
    @State private var quickHour: Int = 0
    @State private var quickMinute: Int = 0
    @State private var quickDay: Int = 1
    @State private var quickWeekday: Int = 1
    @State private var quickInterval: Int = 5  // for "every N minutes"

    @State private var minuteField: String = "0"
    @State private var hourField: String = "*"
    @State private var domField: String = "*"
    @State private var monthField: String = "*"
    @State private var dowField: String = "*"

    @State private var rawExpression: String = ""
    @State private var commandText: String = ""
    @State private var commentText: String = ""
    @State private var initializedForId: UUID?

    enum QuickKind: String, CaseIterable, Identifiable {
        case everyMinute
        case everyNMinutes
        case everyHour
        case everyDay
        case everyWeek
        case everyMonth
        case atReboot

        var id: String { rawValue }
        var label: String {
            switch self {
            case .everyMinute:    return "Every minute"
            case .everyNMinutes:  return "Every N minutes"
            case .everyHour:      return "Every hour, on the hour"
            case .everyDay:       return "Every day at HH:MM"
            case .everyWeek:      return "Every week on a day at HH:MM"
            case .everyMonth:     return "Every month on day N at HH:MM"
            case .atReboot:       return "At reboot"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modePicker
                modeContent
                Divider()
                commandSection
                Divider()
                runNowSection
            }
            .padding(20)
        }
        .onAppear { hydrate() }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { m in
                Text(m.label).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: mode) { _, _ in commitSchedule() }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .quick:
            quickEditor
        case .custom:
            customEditor
        case .raw:
            rawEditor
        }
    }

    // MARK: - Quick

    private var quickEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Kind", selection: $quickKind) {
                ForEach(QuickKind.allCases) { k in
                    Text(k.label).tag(k)
                }
            }
            .onChange(of: quickKind) { _, _ in commitSchedule() }

            switch quickKind {
            case .everyMinute, .everyHour, .atReboot:
                EmptyView()
            case .everyNMinutes:
                Stepper("Every \(quickInterval) minutes", value: $quickInterval, in: 1...59)
                    .onChange(of: quickInterval) { _, _ in commitSchedule() }
            case .everyDay:
                hourMinutePickers
            case .everyWeek:
                hourMinutePickers
                Picker("On", selection: $quickWeekday) {
                    Text("Sunday").tag(0)
                    Text("Monday").tag(1)
                    Text("Tuesday").tag(2)
                    Text("Wednesday").tag(3)
                    Text("Thursday").tag(4)
                    Text("Friday").tag(5)
                    Text("Saturday").tag(6)
                }
                .onChange(of: quickWeekday) { _, _ in commitSchedule() }
            case .everyMonth:
                hourMinutePickers
                Stepper("On day \(quickDay)", value: $quickDay, in: 1...28)
                    .onChange(of: quickDay) { _, _ in commitSchedule() }
            }
        }
    }

    private var hourMinutePickers: some View {
        HStack {
            Text("at")
                .foregroundStyle(.secondary)
            Picker("", selection: $quickHour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d", h)).tag(h) }
            }
            .frame(width: 70)
            .labelsHidden()
            .onChange(of: quickHour) { _, _ in commitSchedule() }
            Text(":")
            Picker("", selection: $quickMinute) {
                ForEach(0..<60, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
            }
            .frame(width: 70)
            .labelsHidden()
            .onChange(of: quickMinute) { _, _ in commitSchedule() }
        }
    }

    // MARK: - Custom

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                fieldColumn("Min", $minuteField, hint: "0–59, *, */N, A-B")
                fieldColumn("Hour", $hourField, hint: "0–23")
                fieldColumn("Day", $domField, hint: "1–31")
                fieldColumn("Month", $monthField, hint: "1–12 / JAN")
                fieldColumn("DOW", $dowField, hint: "0–6 / SUN")
            }
            Text("Resulting expression: \(currentExpression)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func fieldColumn(_ label: String, _ binding: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.bold())
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: binding.wrappedValue) { _, _ in commitSchedule() }
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var currentExpression: String {
        "\(minuteField) \(hourField) \(domField) \(monthField) \(dowField)"
    }

    // MARK: - Raw

    private var rawEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("e.g. */5 * * * * or @daily", text: $rawExpression)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: rawExpression) { _, _ in commitSchedule() }
            Text("Anything cron understands. Validation runs at install time.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Command + comment

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Command").font(.caption.bold())
            TextField("e.g. /usr/bin/python3 /home/me/script.py", text: $commandText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...5)
                .onChange(of: commandText) { _, _ in commitCommand() }

            Text("Comment (optional)").font(.caption.bold()).padding(.top, 6)
            TextField("Description, e.g. 'Nightly backup'", text: $commentText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: commentText) { _, _ in commitCommand() }
        }
    }

    // MARK: - Run now

    private var runNowSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    onRunNow(currentEntry())
                } label: {
                    Label("Run now", systemImage: "play.circle")
                }
                Spacer()
            }
            if let result = runNowResult {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - State plumbing

    private func hydrate() {
        guard initializedForId != entry.id else { return }
        initializedForId = entry.id

        commandText = entry.command
        commentText = entry.comment ?? ""
        rawExpression = entry.schedule.expression

        switch entry.schedule {
        case .standard(let m, let h, let d, let mo, let w):
            minuteField = m; hourField = h; domField = d; monthField = mo; dowField = w
            // Try to detect a quick pattern.
            if m == "*" && h == "*" && d == "*" && mo == "*" && w == "*" {
                mode = .quick; quickKind = .everyMinute
            } else if m.hasPrefix("*/"), let n = Int(m.dropFirst(2)),
                      h == "*", d == "*", mo == "*", w == "*" {
                mode = .quick; quickKind = .everyNMinutes; quickInterval = n
            } else if m == "0" && h == "*" && d == "*" && mo == "*" && w == "*" {
                mode = .quick; quickKind = .everyHour
            } else if let mInt = Int(m), let hInt = Int(h),
                      d == "*", mo == "*", w == "*" {
                mode = .quick; quickKind = .everyDay; quickHour = hInt; quickMinute = mInt
            } else if let mInt = Int(m), let hInt = Int(h), let wInt = Int(w),
                      d == "*", mo == "*" {
                mode = .quick; quickKind = .everyWeek
                quickHour = hInt; quickMinute = mInt; quickWeekday = wInt
            } else if let mInt = Int(m), let hInt = Int(h), let dInt = Int(d),
                      mo == "*", w == "*" {
                mode = .quick; quickKind = .everyMonth
                quickHour = hInt; quickMinute = mInt; quickDay = dInt
            } else {
                mode = .custom
            }
        case .shorthand(let s):
            mode = .quick
            switch s {
            case "@reboot": quickKind = .atReboot
            case "@hourly": quickKind = .everyHour
            case "@daily", "@midnight": quickKind = .everyDay; quickHour = 0; quickMinute = 0
            case "@weekly": quickKind = .everyWeek; quickHour = 0; quickMinute = 0; quickWeekday = 0
            case "@monthly": quickKind = .everyMonth; quickHour = 0; quickMinute = 0; quickDay = 1
            default: mode = .raw
            }
        case .raw:
            mode = .raw
        }
    }

    private func commitSchedule() {
        let new = currentEntry()
        if new.schedule != entry.schedule {
            onChange(new)
        }
    }

    private func commitCommand() {
        let new = currentEntry()
        if new.command != entry.command || new.comment != entry.comment {
            onChange(new)
        }
    }

    private func currentEntry() -> CronEntry {
        let schedule = currentSchedule()
        return CronEntry(
            id: entry.id,
            schedule: schedule,
            command: commandText,
            comment: commentText.isEmpty ? nil : commentText
        )
    }

    private func currentSchedule() -> CronSchedule {
        switch mode {
        case .quick:
            switch quickKind {
            case .everyMinute:
                return .standard(minute: "*", hour: "*", dom: "*", month: "*", dow: "*")
            case .everyNMinutes:
                return .standard(minute: "*/\(quickInterval)", hour: "*", dom: "*", month: "*", dow: "*")
            case .everyHour:
                return .standard(minute: "0", hour: "*", dom: "*", month: "*", dow: "*")
            case .everyDay:
                return .standard(minute: "\(quickMinute)", hour: "\(quickHour)", dom: "*", month: "*", dow: "*")
            case .everyWeek:
                return .standard(minute: "\(quickMinute)", hour: "\(quickHour)", dom: "*", month: "*", dow: "\(quickWeekday)")
            case .everyMonth:
                return .standard(minute: "\(quickMinute)", hour: "\(quickHour)", dom: "\(quickDay)", month: "*", dow: "*")
            case .atReboot:
                return .shorthand("@reboot")
            }
        case .custom:
            return .standard(
                minute: minuteField,
                hour: hourField,
                dom: domField,
                month: monthField,
                dow: dowField
            )
        case .raw:
            let trimmed = rawExpression.trimmingCharacters(in: .whitespaces)
            if CronSchedule.allShorthands.contains(trimmed) {
                return .shorthand(trimmed)
            }
            return .raw(trimmed)
        }
    }
}
