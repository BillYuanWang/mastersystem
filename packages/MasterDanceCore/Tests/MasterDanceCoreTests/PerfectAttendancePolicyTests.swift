import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Perfect attendance policy")
struct PerfectAttendancePolicyTests {
    @Test("Present history remains currently perfect")
    func currentPerfect() throws {
        let fixture = try Fixture()
        let record = Attendance(
            sessionID: fixture.firstSession.id,
            studentID: fixture.studentID,
            enrollmentID: fixture.enrollment.id,
            status: .present,
            recordedAt: fixture.firstSession.endsAt
        )

        #expect(fixture.evaluate(asOf: fixture.wednesday, attendance: [record]) == .currentPerfect)
    }

    @Test("A leave is makeup-perfect through its Sunday deadline")
    func leaveWeekIsYellow() throws {
        let fixture = try Fixture()
        let leave = fixture.leave(for: fixture.firstSession)

        #expect(
            fixture.evaluate(
                asOf: fixture.saturday,
                leaveRequests: [leave]
            ) == .makeupPerfect
        )
    }

    @Test("A future leave in the current week turns yellow before class starts")
    func upcomingLeaveThisWeekIsYellow() throws {
        let fixture = try Fixture()
        let leave = fixture.leave(for: fixture.fridaySession)

        #expect(
            fixture.evaluate(
                asOf: fixture.wednesday,
                leaveRequests: [leave]
            ) == .makeupPerfect
        )
    }

    @Test("An on-time or advance makeup returns to current-perfect on Monday")
    func completedMakeupReturnsGreen() throws {
        let fixture = try Fixture()
        let leave = fixture.leave(for: fixture.firstSession)
        let makeup = Attendance(
            sessionID: fixture.advanceMakeupSession.id,
            studentID: fixture.studentID,
            makeupForSessionID: fixture.firstSession.id,
            status: .makeup,
            recordedAt: fixture.advanceMakeupSession.endsAt
        )

        #expect(
            fixture.evaluate(
                asOf: fixture.nextMonday,
                attendance: [makeup],
                leaveRequests: [leave]
            ) == .currentPerfect
        )
    }

    @Test("An unfulfilled leave permanently loses perfect attendance after Sunday")
    func missedDeadlineIsRed() throws {
        let fixture = try Fixture()
        let leave = fixture.leave(for: fixture.firstSession)

        #expect(fixture.evaluate(asOf: fixture.nextMonday, leaveRequests: [leave]) == .notPerfect)
        #expect(fixture.evaluate(asOf: fixture.followingMonday, leaveRequests: [leave]) == .notPerfect)
    }

    @Test("A makeup after the deadline cannot restore perfect attendance")
    func lateMakeupStaysRed() throws {
        let fixture = try Fixture()
        let leave = fixture.leave(for: fixture.firstSession)
        let makeup = Attendance(
            sessionID: fixture.lateMakeupSession.id,
            studentID: fixture.studentID,
            makeupForSessionID: fixture.firstSession.id,
            status: .makeup,
            recordedAt: fixture.lateMakeupSession.endsAt
        )

        #expect(
            fixture.evaluate(
                asOf: fixture.followingMonday,
                attendance: [makeup],
                leaveRequests: [leave]
            ) == .notPerfect
        )
    }

    @Test("An explicit absence loses perfect attendance even when later made up")
    func absenceIsRed() throws {
        let fixture = try Fixture()
        let absence = Attendance(
            sessionID: fixture.firstSession.id,
            studentID: fixture.studentID,
            enrollmentID: fixture.enrollment.id,
            status: .absent,
            recordedAt: fixture.firstSession.endsAt
        )
        let makeup = Attendance(
            sessionID: fixture.advanceMakeupSession.id,
            studentID: fixture.studentID,
            makeupForSessionID: fixture.firstSession.id,
            status: .makeup,
            recordedAt: fixture.advanceMakeupSession.endsAt
        )

        #expect(
            fixture.evaluate(
                asOf: fixture.nextMonday,
                attendance: [absence, makeup]
            ) == .notPerfect
        )
    }

    @Test("A valid status becomes term-perfect after the final day")
    func termPerfect() throws {
        let fixture = try Fixture()
        #expect(fixture.evaluate(asOf: fixture.afterTerm) == .termPerfect)
    }
}

private struct Fixture {
    let calendar: Calendar
    let term: Term
    let courseID = CourseID()
    let guestCourseID = CourseID()
    let studentID = StudentID()
    let enrollment: Enrollment
    let firstSession: ClassSession
    let fridaySession: ClassSession
    let advanceMakeupSession: ClassSession
    let lateMakeupSession: ClassSession
    let wednesday: Date
    let saturday: Date
    let nextMonday: Date
    let followingMonday: Date
    let afterTerm: Date

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        calendar.firstWeekday = 2
        self.calendar = calendar

        let termStart = try Self.date(2026, 7, 6, 0, calendar: calendar)
        let termEnd = try Self.date(2026, 7, 19, 0, calendar: calendar)
        term = Term(name: "Summer", startsOn: termStart, endsOn: termEnd, status: .open)
        enrollment = Enrollment(
            termID: term.id,
            courseID: courseID,
            studentID: studentID,
            enrolledAt: termStart
        )
        firstSession = ClassSession(
            courseID: courseID,
            startsAt: try Self.date(2026, 7, 6, 16, calendar: calendar),
            endsAt: try Self.date(2026, 7, 6, 17, calendar: calendar)
        )
        fridaySession = ClassSession(
            courseID: courseID,
            startsAt: try Self.date(2026, 7, 10, 16, calendar: calendar),
            endsAt: try Self.date(2026, 7, 10, 17, calendar: calendar)
        )
        advanceMakeupSession = ClassSession(
            courseID: guestCourseID,
            startsAt: try Self.date(2026, 7, 5, 10, calendar: calendar),
            endsAt: try Self.date(2026, 7, 5, 11, calendar: calendar)
        )
        lateMakeupSession = ClassSession(
            courseID: guestCourseID,
            startsAt: try Self.date(2026, 7, 13, 10, calendar: calendar),
            endsAt: try Self.date(2026, 7, 13, 11, calendar: calendar)
        )
        wednesday = try Self.date(2026, 7, 8, 12, calendar: calendar)
        saturday = try Self.date(2026, 7, 11, 12, calendar: calendar)
        nextMonday = try Self.date(2026, 7, 13, 0, calendar: calendar)
        followingMonday = try Self.date(2026, 7, 20, 0, calendar: calendar)
        afterTerm = try Self.date(2026, 7, 20, 0, calendar: calendar)
    }

    func leave(for session: ClassSession) -> LeaveRequest {
        LeaveRequest(
            sessionID: session.id,
            studentID: studentID,
            enrollmentID: enrollment.id,
            source: .administrator,
            submittedAt: session.startsAt.addingTimeInterval(-86_400)
        )
    }

    func evaluate(
        asOf date: Date,
        attendance: [Attendance] = [],
        leaveRequests: [LeaveRequest] = []
    ) -> PerfectAttendanceStatus? {
        PerfectAttendancePolicy.evaluate(
            term: term,
            enrollments: [enrollment],
            sessions: [firstSession, fridaySession, advanceMakeupSession, lateMakeupSession],
            attendance: attendance,
            leaveRequests: leaveRequests,
            studentID: studentID,
            asOf: date,
            calendar: calendar
        )
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
