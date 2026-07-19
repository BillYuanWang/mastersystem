import Foundation
import Supabase
import Testing
@testable import MasterDanceAdmin

@Suite("Session-aware auth storage")
struct SessionAwareAuthStorageTests {
    private let sessionKey = "supabase.auth.token"
    private let verifierKey = "supabase.auth.token-code-verifier"

    @Test("Remembered sessions are written to backing storage")
    func persistsRememberedSession() throws {
        let backing = FakeAuthStorage()
        let storage = SessionAwareAuthStorage(backing: backing, persistsSession: true)
        let session = Data("session".utf8)

        try storage.store(key: sessionKey, value: session)

        #expect(backing.value(for: sessionKey) == session)
    }

    @Test("Unremembered sessions remain process-only")
    func keepsUnrememberedSessionInMemory() throws {
        let backing = FakeAuthStorage()
        let storage = SessionAwareAuthStorage(backing: backing, persistsSession: false)
        let session = Data("session".utf8)

        try storage.store(key: sessionKey, value: session)

        #expect(try storage.retrieve(key: sessionKey) == session)
        #expect(backing.value(for: sessionKey) == nil)
    }

    @Test("PKCE verifier persists even when the session does not")
    func preservesPasswordResetVerifier() throws {
        let backing = FakeAuthStorage()
        let storage = SessionAwareAuthStorage(backing: backing, persistsSession: false)
        let verifier = Data("verifier".utf8)

        try storage.store(key: verifierKey, value: verifier)

        #expect(backing.value(for: verifierKey) == verifier)
    }

    @Test("Disabling persistence removes disk state without ending the process session")
    func togglesPersistence() throws {
        let backing = FakeAuthStorage()
        let storage = SessionAwareAuthStorage(backing: backing, persistsSession: true)
        let session = Data("session".utf8)
        try storage.store(key: sessionKey, value: session)

        storage.setSessionPersistenceEnabled(false)

        #expect(backing.value(for: sessionKey) == nil)
        #expect(try storage.retrieve(key: sessionKey) == session)

        storage.setSessionPersistenceEnabled(true)

        #expect(backing.value(for: sessionKey) == session)
    }
}

private final class FakeAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) {
        lock.withLock {
            values[key] = value
        }
    }

    func retrieve(key: String) -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) {
        lock.withLock {
            values[key] = nil
        }
    }

    func value(for key: String) -> Data? {
        lock.withLock { values[key] }
    }
}
