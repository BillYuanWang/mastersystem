import Foundation

public enum LeaveRequestPolicy {
    public static let guardianMinimumNotice: TimeInterval = 12 * 60 * 60

    public static func guardianDeadline(for sessionStartsAt: Date) -> Date {
        sessionStartsAt.addingTimeInterval(-guardianMinimumNotice)
    }

    public static func canGuardianSubmit(
        for sessionStartsAt: Date,
        at submissionDate: Date = Date()
    ) -> Bool {
        submissionDate <= guardianDeadline(for: sessionStartsAt)
    }
}
