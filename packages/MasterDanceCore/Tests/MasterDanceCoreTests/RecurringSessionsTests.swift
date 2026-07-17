import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Recurring session planning")
struct RecurringSessionsTests {
    @Test("Weekly dates stay inside the range and honor exclusions")
    func buildsWeeklyDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startsOn = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        let endsOn = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)))
        let excluded = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 17)))
        let plan = WeeklySessionPlan(
            courseID: CourseID(),
            startsOn: startsOn,
            endsOn: endsOn,
            weekday: 2,
            startTime: SessionClockTime(hour: 16, minute: 0),
            endTime: SessionClockTime(hour: 17, minute: 15),
            excludedDates: [excluded]
        )

        let dates = try RecurringSessionBuilder.occurrenceDates(for: plan, calendar: calendar)

        #expect(dates.count == 4)
        #expect(!dates.contains(excluded))
        #expect(dates.allSatisfy { calendar.component(.weekday, from: $0) == 2 })
    }

    @Test("Generated sessions preserve course identity and clock time")
    func buildsSessions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        let courseID = CourseID()
        let plan = WeeklySessionPlan(
            courseID: courseID,
            startsOn: day,
            endsOn: day,
            weekday: 2,
            startTime: SessionClockTime(hour: 9, minute: 30),
            endTime: SessionClockTime(hour: 10, minute: 45)
        )

        let session = try #require(RecurringSessionBuilder.sessions(for: plan, calendar: calendar).first)

        #expect(session.courseID == courseID)
        #expect(calendar.component(.hour, from: session.startsAt) == 9)
        #expect(calendar.component(.minute, from: session.startsAt) == 30)
        #expect(session.endsAt.timeIntervalSince(session.startsAt) == 75 * 60)
    }

    @Test("Invalid clock ranges are rejected")
    func rejectsInvalidTimes() {
        let plan = WeeklySessionPlan(
            courseID: CourseID(),
            startsOn: .distantPast,
            endsOn: .distantFuture,
            weekday: 2,
            startTime: SessionClockTime(hour: 18, minute: 0),
            endTime: SessionClockTime(hour: 17, minute: 0)
        )

        #expect(throws: RecurringSessionError.invalidTimeRange) {
            try RecurringSessionBuilder.sessions(for: plan)
        }
    }

    @Test("Dry runs block writes when validation errors exist")
    func dryRunReadiness() {
        let summary = MigrationEntitySummary(
            entity: .course,
            sourceRows: 2,
            validRows: 1,
            skippedRows: 1,
            proposedInserts: 1,
            proposedUpdates: 0
        )
        let report = MigrationDryRunReport(
            generatedAt: .distantPast,
            sourceFingerprint: "example",
            summaries: [summary],
            issues: [
                MigrationIssue(
                    severity: .error,
                    entity: .course,
                    sourceRow: 2,
                    field: "room",
                    message: "Unknown room"
                )
            ]
        )

        #expect(!report.isReadyToApply)
        #expect(report.proposedWriteCount == 1)
    }
}
