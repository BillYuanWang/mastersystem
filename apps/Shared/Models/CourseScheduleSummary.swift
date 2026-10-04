import Foundation
import MasterDanceCore

struct CourseScheduleSummary {
    struct Slot {
        let weekday: Int
        let startMinutes: Int
        let endMinutes: Int
        let sessionCount: Int
        let firstDate: Date
        let lastDate: Date
        let dates: [Date]

        var key: String { "\(weekday)-\(startMinutes)-\(endMinutes)" }
        var sortKey: Int { ((weekday + 5) % 7) * 1_440 + startMinutes }

        var label: String {
            let day = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][weekday - 1]
            return "\(day) \(clock(startMinutes))–\(clock(endMinutes))"
        }

        private func clock(_ minutes: Int) -> String {
            String(format: "%02d:%02d", minutes / 60, minutes % 60)
        }
    }

    let slots: [Slot]

    var primary: Slot? { slots.min { $0.sortKey < $1.sortKey } }

    var label: String {
        guard let primary else { return "未排课" }
        return slots.count == 1 ? primary.label : "分阶段排课 · " + slots.map(\.label).joined(separator: " / ")
    }

    var filterKeys: Set<String> {
        slots.isEmpty ? ["none"] : Set(slots.map(\.key))
    }

    func matches(_ selectedKeys: Set<String>) -> Bool {
        selectedKeys.isEmpty || !filterKeys.isDisjoint(with: selectedKeys)
    }

    func details(calendar: Calendar) -> String {
        guard !slots.isEmpty else { return "未排课" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy/MM/dd"
        return slots.map { slot in
            "\(slot.label) · \(slot.sessionCount) 节\n"
                + slot.dates.map { formatter.string(from: $0) }.joined(separator: "、")
        }.joined(separator: "\n")
    }

    init(sessions: [ClassSession], calendar: Calendar) {
        let grouped = Dictionary(grouping: sessions.filter { $0.status != .cancelled }) { session in
            let weekday = calendar.component(.weekday, from: session.startsAt)
            let start = calendar.component(.hour, from: session.startsAt) * 60
                + calendar.component(.minute, from: session.startsAt)
            let end = calendar.component(.hour, from: session.endsAt) * 60
                + calendar.component(.minute, from: session.endsAt)
            return [weekday, start, end]
        }
        slots = grouped.map { key, values in
            Slot(
                weekday: key[0],
                startMinutes: key[1],
                endMinutes: key[2],
                sessionCount: values.count,
                firstDate: values.map(\.startsAt).min()!,
                lastDate: values.map(\.startsAt).max()!,
                dates: values.map(\.startsAt).sorted()
            )
        }.sorted { left, right in
            if left.firstDate != right.firstDate { return left.firstDate < right.firstDate }
            if left.sortKey != right.sortKey { return left.sortKey < right.sortKey }
            return left.endMinutes < right.endMinutes
        }
    }
}
