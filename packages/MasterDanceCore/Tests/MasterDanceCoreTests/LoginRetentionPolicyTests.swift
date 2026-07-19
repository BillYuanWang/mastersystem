import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Login retention policy")
struct LoginRetentionPolicyTests {
    private let anchor = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Remembered login remains valid before 180 days")
    func validBeforeLimit() {
        let now = anchor.addingTimeInterval(LoginRetentionPolicy.maximumDuration - 1)

        #expect(LoginRetentionPolicy.canRestore(
            rememberLogin: true,
            authenticatedAt: anchor,
            now: now
        ))
    }

    @Test("Remembered login expires exactly at 180 days")
    func expiresAtLimit() {
        let now = LoginRetentionPolicy.expirationDate(authenticatedAt: anchor)

        #expect(!LoginRetentionPolicy.canRestore(
            rememberLogin: true,
            authenticatedAt: anchor,
            now: now
        ))
    }

    @Test("Unremembered or missing authentication cannot restore")
    func requiresRememberedAnchor() {
        #expect(!LoginRetentionPolicy.canRestore(
            rememberLogin: false,
            authenticatedAt: anchor,
            now: anchor
        ))
        #expect(!LoginRetentionPolicy.canRestore(
            rememberLogin: true,
            authenticatedAt: nil,
            now: anchor
        ))
    }

    @Test("Future authentication timestamps are rejected")
    func rejectsFutureTimestamp() {
        #expect(!LoginRetentionPolicy.isWithinMaximumDuration(
            authenticatedAt: anchor.addingTimeInterval(1),
            now: anchor
        ))
    }
}
