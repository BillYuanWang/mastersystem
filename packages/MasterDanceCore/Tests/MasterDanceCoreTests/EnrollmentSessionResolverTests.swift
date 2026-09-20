import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Dated enrollment and billing sessions")
struct EnrollmentSessionResolverTests {
    let courseID = CourseID()
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    @Test("Late per-session registration includes only selected Saturdays")
    func selectedSaturdays() throws {
        let sessions = try fixture()
        var enrollment = enrollment()
        enrollment.registrationMode = .perSession
        enrollment.selectedSessionIDs = [sessions[3].id, sessions[4].id]
        let resolved = EnrollmentSessionResolver.billableSessions(enrollment: enrollment, sessions: sessions, calendar: calendar)
        #expect(resolved.map(\.id) == [sessions[3].id, sessions[4].id])
        #expect(resolved.allSatisfy { calendar.component(.weekday, from: $0.startsAt) == 7 })
        #expect(BillingCalculator.estimate(enrollment: enrollment, sessions: sessions, calendar: calendar).normalSessionCount == 2)
    }

    @Test("Full-term dates, trials, cancellations, and foreign courses share one billing rule")
    func fullTermCoverage() throws {
        var sessions = try fixture()
        var enrollment = enrollment()
        enrollment.billingStartsOn = sessions[1].startsAt
        sessions[4].status = .cancelled
        sessions.append(ClassSession(courseID: CourseID(), startsAt: sessions[2].startsAt, endsAt: sessions[2].endsAt))
        let result = EnrollmentSessionResolver.billableSessions(
            enrollment: enrollment, sessions: sessions, trialSessionIDs: [sessions[2].id], calendar: calendar
        )
        #expect(result.map(\.id) == [sessions[1].id, sessions[3].id])
        let estimate = BillingCalculator.estimate(enrollment: enrollment, sessions: sessions, trialSessionIDs: [sessions[2].id], calendar: calendar)
        #expect(estimate.normalSessionCount == result.count)
        #expect(estimate.tuitionBeforeDiscountCents == 7_000)
    }

    @Test("Moving selected sessions earlier does not remove a per-session charge")
    func earlierMoveKeepsSelectedCharge() throws {
        var sessions = try fixture()
        var enrollment = enrollment()
        enrollment.registrationMode = .perSession
        enrollment.selectedSessionIDs = [sessions[3].id]
        enrollment.billingStartsOn = sessions[3].startsAt
        sessions[3].startsAt.addTimeInterval(-86400)
        sessions[3].endsAt.addTimeInterval(-86400)
        let resolved = EnrollmentSessionResolver.billableSessions(enrollment: enrollment, sessions: sessions, calendar: calendar)
        #expect(resolved.map(\.id) == [sessions[3].id])
        #expect(BillingCalculator.estimate(enrollment: enrollment, sessions: sessions, calendar: calendar).tuitionBeforeDiscountCents == 3500)
    }

    @Test("Rescheduling preserves session IDs and does not rewrite issue-time evidence")
    func preservesIdentityAndSnapshot() throws {
        let sessions = try fixture()
        let snapshot = BillingScheduleSnapshot(
            courseName: "Performance", studentName: "Test learner", registrationMode: .fullTerm,
            timeZoneIdentifier: calendar.timeZone.identifier,
            sessions: sessions.map { .init(session: $0, room: "Small room", instructor: "Test teacher") }
        )
        let moved = CourseSessionEditing.moving(sessions, from: sessions[3].startsAt, through: sessions[4].startsAt,
            weekday: 1, startTime: .init(hour: 12, minute: 0), endTime: .init(hour: 13, minute: 0), calendar: calendar)
        #expect(moved.map(\.id) == sessions.map(\.id))
        #expect(moved[0] == sessions[0])
        #expect(moved[3].startsAt != sessions[3].startsAt)
        #expect(snapshot.sessions[3].startsAt == sessions[3].startsAt)
        let item = BillingInvoiceLineItem(invoiceID: BillingInvoiceID(), kind: .tuition, title: "Tuition",
            scheduleSnapshot: snapshot, quantity: 5, unitAmountCents: 3_500, amountCents: 17_500)
        let encoded = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(BillingInvoiceLineItem.self, from: encoded) == item)
    }

    @Test("Legacy invoice items without snapshots remain readable")
    func legacyCompatibility() throws {
        let item = BillingInvoiceLineItem(invoiceID: BillingInvoiceID(), kind: .manual, title: "Old item", unitAmountCents: 100, amountCents: 100)
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(BillingInvoiceLineItem.self, from: data).scheduleSnapshot == nil)
    }

    private func enrollment() -> Enrollment {
        Enrollment(termID: TermID(), courseID: courseID, studentID: StudentID(), enrolledAt: Date(), unitPriceCents: 3_500)
    }

    private func fixture() throws -> [ClassSession] {
        try ["2026-08-23T18:00:00Z", "2026-08-30T18:00:00Z", "2026-09-06T18:00:00Z", "2026-09-12T18:00:00Z", "2026-09-19T18:00:00Z"].map {
            let start = try #require(ISO8601DateFormatter().date(from: $0))
            return ClassSession(courseID: courseID, startsAt: start, endsAt: start.addingTimeInterval(3_600))
        }
    }
}
