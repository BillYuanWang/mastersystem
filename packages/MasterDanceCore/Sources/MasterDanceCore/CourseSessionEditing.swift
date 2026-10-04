import Foundation

public enum CourseSessionEditing {
    public static func moving(
        _ sessions: [ClassSession], from: Date, through: Date,
        weekday: Int, startTime: SessionClockTime, endTime: SessionClockTime,
        calendar: Calendar
    ) -> [ClassSession] {
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: through)
        return sessions.map { session in
            let day = calendar.startOfDay(for: session.startsAt)
            guard day >= first, day <= last, session.status != .cancelled else { return session }
            let oldWeekday = (calendar.component(.weekday, from: day) + 5) % 7
            let newWeekday = (weekday + 5) % 7
            guard let date = calendar.date(byAdding: .day, value: newWeekday - oldWeekday, to: day),
                  let start = calendar.date(bySettingHour: startTime.hour, minute: startTime.minute, second: 0, of: date),
                  let end = calendar.date(bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: date)
            else { return session }
            var moved = session
            moved.startsAt = start
            moved.endsAt = end
            return moved
        }
    }
}
