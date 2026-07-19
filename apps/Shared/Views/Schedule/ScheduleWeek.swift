#if os(macOS)
import Foundation
import MasterDanceCore

enum ScheduleWeek {
    static let dayCount = 7

    static func days(
        startingAt weekStart: Date,
        calendar: Calendar = .masterDance
    ) -> [Date] {
        (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    static func endExclusive(
        startingAt weekStart: Date,
        calendar: Calendar = .masterDance
    ) -> Date? {
        calendar.date(byAdding: .day, value: dayCount, to: weekStart)
    }

    static func rangeLabel(
        startingAt weekStart: Date,
        includesYear: Bool = false,
        calendar: Calendar = .masterDance
    ) -> String {
        guard let weekEnd = calendar.date(byAdding: .day, value: dayCount - 1, to: weekStart) else {
            return weekStart.formatted(.dateTime.month(.abbreviated).day()).uppercased()
        }

        let startMonth = weekStart.formatted(.dateTime.month(.abbreviated)).uppercased()
        let endMonth = weekEnd.formatted(.dateTime.month(.abbreviated)).uppercased()
        let startDay = calendar.component(.day, from: weekStart)
        let endDay = calendar.component(.day, from: weekEnd)
        let startYear = calendar.component(.year, from: weekStart)
        let endYear = calendar.component(.year, from: weekEnd)

        if startYear != endYear {
            return "\(startMonth) \(startDay), \(startYear)–\(endMonth) \(endDay), \(endYear)"
        }

        let range = startMonth == endMonth
            ? "\(startMonth) \(startDay)–\(endDay)"
            : "\(startMonth) \(startDay)–\(endMonth) \(endDay)"
        return includesYear ? "\(range), \(startYear)" : range
    }
}
#endif
