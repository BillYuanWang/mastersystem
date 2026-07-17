import Foundation

public struct SessionClockTime: Codable, Equatable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    fileprivate var minuteOfDay: Int { hour * 60 + minute }

    fileprivate var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }
}

public struct WeeklySessionPlan: Equatable, Sendable {
    public let courseID: CourseID
    public var startsOn: Date
    public var endsOn: Date
    public var weekday: Int
    public var startTime: SessionClockTime
    public var endTime: SessionClockTime
    public var excludedDates: Set<Date>

    public init(
        courseID: CourseID,
        startsOn: Date,
        endsOn: Date,
        weekday: Int,
        startTime: SessionClockTime,
        endTime: SessionClockTime,
        excludedDates: Set<Date> = []
    ) {
        self.courseID = courseID
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.weekday = weekday
        self.startTime = startTime
        self.endTime = endTime
        self.excludedDates = excludedDates
    }
}

public enum RecurringSessionError: Error, Equatable, Sendable {
    case invalidDateRange
    case invalidWeekday
    case invalidTimeRange
    case dateConstructionFailed
}

public enum RecurringSessionBuilder {
    public static func occurrenceDates(
        for plan: WeeklySessionPlan,
        calendar: Calendar = .current
    ) throws -> [Date] {
        try validate(plan)

        let firstDay = calendar.startOfDay(for: plan.startsOn)
        let lastDay = calendar.startOfDay(for: plan.endsOn)
        let excludedDays = Set(plan.excludedDates.map(calendar.startOfDay(for:)))

        var cursor = firstDay
        while calendar.component(.weekday, from: cursor) != plan.weekday {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                throw RecurringSessionError.dateConstructionFailed
            }
            cursor = nextDay
        }

        var dates: [Date] = []
        while calendar.compare(cursor, to: lastDay, toGranularity: .day) != .orderedDescending {
            if !excludedDays.contains(calendar.startOfDay(for: cursor)) {
                dates.append(cursor)
            }
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else {
                throw RecurringSessionError.dateConstructionFailed
            }
            cursor = nextWeek
        }
        return dates
    }

    public static func sessions(
        for plan: WeeklySessionPlan,
        calendar: Calendar = .current
    ) throws -> [ClassSession] {
        try occurrenceDates(for: plan, calendar: calendar).map { day in
            var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
            startComponents.hour = plan.startTime.hour
            startComponents.minute = plan.startTime.minute

            var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
            endComponents.hour = plan.endTime.hour
            endComponents.minute = plan.endTime.minute

            guard
                let startsAt = calendar.date(from: startComponents),
                let endsAt = calendar.date(from: endComponents)
            else {
                throw RecurringSessionError.dateConstructionFailed
            }

            return ClassSession(
                courseID: plan.courseID,
                startsAt: startsAt,
                endsAt: endsAt
            )
        }
    }

    private static func validate(_ plan: WeeklySessionPlan) throws {
        guard plan.startsOn <= plan.endsOn else {
            throw RecurringSessionError.invalidDateRange
        }
        guard (1...7).contains(plan.weekday) else {
            throw RecurringSessionError.invalidWeekday
        }
        guard
            plan.startTime.isValid,
            plan.endTime.isValid,
            plan.startTime.minuteOfDay < plan.endTime.minuteOfDay
        else {
            throw RecurringSessionError.invalidTimeRange
        }
    }
}
