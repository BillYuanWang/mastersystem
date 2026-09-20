import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Course weekly schedule summary")
struct CourseScheduleSummaryTests {
    @Test("Three early Sunday moves do not hide fourteen regular Saturday classes")
    func summarizesTemporaryMoves() throws {
        let summary = CourseScheduleSummary(sessions: try movedSessions(), calendar: calendar)
        #expect(summary.primary?.weekday == 7)
        #expect(summary.primary?.sessionCount == 14)
        #expect(summary.slots.count == 2)
        #expect(summary.label == "分阶段排课 · 周日 11:00–12:00 / 周六 11:00–12:00")
        #expect(summary.details(calendar: calendar).contains("周日 11:00–12:00 · 3 节"))
        #expect(summary.details(calendar: calendar).contains("2026/08/23、2026/08/30、2026/09/06"))
    }

    @Test("Either the regular slot or the temporary slot can find the course")
    func filtersEverySlot() throws {
        let summary = CourseScheduleSummary(sessions: try movedSessions(), calendar: calendar)
        #expect(summary.matches(["7-660-720"]))
        #expect(summary.matches(["1-660-720"]))
        #expect(summary.matches([]))
        #expect(!summary.matches(["2-660-720"]))
    }

    @Test("Input order and daylight saving do not create extra weekly slots")
    func stableAcrossInputAndDST() throws {
        let sessions = try movedSessions()
        let summary = CourseScheduleSummary(sessions: Array(sessions.reversed()), calendar: calendar)
        let ordered = CourseScheduleSummary(sessions: sessions, calendar: calendar)
        #expect(summary.slots.map(\.key) == ordered.slots.map(\.key))
        #expect(summary.slots.map(\.sessionCount) == [3, 14])
    }

    @Test("All slots stay visible in chronological order; sorting uses weekday order")
    func breaksTiesDeterministically() throws {
        let summary = CourseScheduleSummary(
            sessions: try [session("2026-08-23T18:00:00Z"), session("2026-09-12T18:00:00Z")],
            calendar: calendar
        )
        #expect(summary.primary?.weekday == 7)
    }

    @Test("Unscheduled and cancelled-only courses keep the no-schedule filter")
    func handlesUnavailableSessions() throws {
        var cancelled = try session("2026-08-23T18:00:00Z")
        cancelled.status = .cancelled
        for sessions in [[], [cancelled]] {
            let summary = CourseScheduleSummary(sessions: sessions, calendar: calendar)
            #expect(summary.primary == nil)
            #expect(summary.label == "未排课")
            #expect(summary.matches(["none"]))
            #expect(!summary.matches(["1-660-720"]))
        }
    }

    @Test("A regular course retains a single slot; distinct end times remain separate")
    func keepsDifferentDurations() throws {
        let first = try session("2026-08-23T18:00:00Z")
        var later = try session("2026-08-30T18:00:00Z")
        let regular = CourseScheduleSummary(sessions: [first, later], calendar: calendar)
        #expect(regular.label == "周日 11:00–12:00")
        #expect(regular.slots.count == 1)
        later.endsAt = later.endsAt.addingTimeInterval(1_800)
        let different = CourseScheduleSummary(sessions: [first, later], calendar: calendar)
        #expect(different.slots.count == 2)
        #expect(different.matches(["1-660-750"]))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func movedSessions() throws -> [ClassSession] {
        try [
            "2026-08-23T18:00:00Z", "2026-08-30T18:00:00Z", "2026-09-06T18:00:00Z",
            "2026-09-12T18:00:00Z", "2026-09-19T18:00:00Z", "2026-09-26T18:00:00Z",
            "2026-10-03T18:00:00Z", "2026-10-10T18:00:00Z", "2026-10-17T18:00:00Z",
            "2026-10-24T18:00:00Z", "2026-10-31T18:00:00Z", "2026-11-07T19:00:00Z",
            "2026-11-14T19:00:00Z", "2026-11-21T19:00:00Z", "2026-12-05T19:00:00Z",
            "2026-12-12T19:00:00Z", "2026-12-19T19:00:00Z"
        ].map(session)
    }

    private func session(_ isoDate: String) throws -> ClassSession {
        let date = try #require(ISO8601DateFormatter().date(from: isoDate))
        return ClassSession(courseID: CourseID(), startsAt: date, endsAt: date.addingTimeInterval(3_600))
    }
}
