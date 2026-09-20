import Foundation
import MasterDanceCore

enum BillingSchedulePresentation {
    static func detail(_ snapshot: BillingScheduleSnapshot, english: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
        let date = DateFormatter()
        date.calendar = calendar
        date.timeZone = calendar.timeZone
        date.locale = Locale(identifier: english ? "en_US" : "zh_Hans_CN")
        date.dateFormat = "yyyy/MM/dd"
        let clock = DateFormatter()
        clock.calendar = calendar
        clock.timeZone = calendar.timeZone
        clock.locale = date.locale
        clock.dateFormat = "EEE HH:mm"
        let end = DateFormatter()
        end.timeZone = calendar.timeZone
        end.dateFormat = "HH:mm"
        let groups = Dictionary(grouping: snapshot.sessions) { session in
            [clock.string(from: session.startsAt), end.string(from: session.endsAt), session.room, session.instructor]
        }.sorted { ($0.value.first?.startsAt ?? .distantPast) < ($1.value.first?.startsAt ?? .distantPast) }
        return groups.map { key, sessions in
            let count = english ? "\(sessions.count) sessions" : "\(sessions.count) 节"
            let dates = sessions.map { date.string(from: $0.startsAt) }.joined(separator: ", ")
            return "\(key[0])–\(key[1]) · \(key[2]) · \(key[3]) · \(count)\n\(dates)"
        }.joined(separator: "\n")
    }
}
