import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Leave request policy")
struct LeaveRequestPolicyTests {
    private let startsAt = Date(timeIntervalSince1970: 200_000)

    @Test("Guardian deadline is twelve hours before class")
    func deadline() {
        #expect(
            LeaveRequestPolicy.guardianDeadline(for: startsAt)
                == startsAt.addingTimeInterval(-12 * 60 * 60)
        )
    }

    @Test("Exactly twelve hours is allowed")
    func exactDeadlineIsAllowed() {
        let deadline = LeaveRequestPolicy.guardianDeadline(for: startsAt)
        #expect(LeaveRequestPolicy.canGuardianSubmit(for: startsAt, at: deadline))
    }

    @Test("A request after the deadline is blocked")
    func afterDeadlineIsBlocked() {
        let deadline = LeaveRequestPolicy.guardianDeadline(for: startsAt)
        #expect(
            !LeaveRequestPolicy.canGuardianSubmit(
                for: startsAt,
                at: deadline.addingTimeInterval(1)
            )
        )
    }
}
