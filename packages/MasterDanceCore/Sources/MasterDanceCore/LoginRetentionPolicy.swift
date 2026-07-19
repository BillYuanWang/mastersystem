import Foundation

public enum LoginRetentionPolicy {
    public static let maximumDuration: TimeInterval = 180 * 24 * 60 * 60

    public static func expirationDate(authenticatedAt: Date) -> Date {
        authenticatedAt.addingTimeInterval(maximumDuration)
    }

    public static func isWithinMaximumDuration(
        authenticatedAt: Date,
        now: Date = Date()
    ) -> Bool {
        let elapsed = now.timeIntervalSince(authenticatedAt)
        return elapsed >= 0 && elapsed < maximumDuration
    }

    public static func canRestore(
        rememberLogin: Bool,
        authenticatedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard rememberLogin, let authenticatedAt else { return false }
        return isWithinMaximumDuration(authenticatedAt: authenticatedAt, now: now)
    }
}
