import Foundation
import MasterDanceCore
import Supabase

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var production: SupabaseConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let urlString = environment["MASTER_DANCE_SUPABASE_URL"]
            ?? "https://szienrktsikxwdnrrudo.supabase.co"
        let publishableKey = environment["MASTER_DANCE_SUPABASE_PUBLISHABLE_KEY"]
            ?? "sb_publishable_oOg7RYMXv83Ofwf2NjgrlA_EcCKFMab"

        guard let url = URL(string: urlString) else {
            preconditionFailure("MASTER_DANCE_SUPABASE_URL is invalid")
        }
        return SupabaseConfiguration(url: url, publishableKey: publishableKey)
    }

    func makeClient() -> SupabaseClient {
        if ProcessInfo.processInfo.environment["MASTER_DANCE_VOLATILE_AUTH"] == "1" {
            return SupabaseClient(
                supabaseURL: url,
                supabaseKey: publishableKey,
                options: SupabaseClientOptions(
                    auth: .init(storage: VolatileAuthStorage())
                )
            )
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryFirstAuthStorage(
                        backing: KeychainLocalStorage()
                    )
                )
            )
        )
    }
}

enum LocalFirstRepositoryFactory {
    static var cacheDirectory: URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("Master Dance", isDirectory: true)
            .appendingPathComponent("Offline Cache", isDirectory: true)
    }

    static func make(
        client: SupabaseClient,
        organizationID: UUID,
        userID: UUID
    ) -> any MasterDanceRepository {
        let remote = SupabaseMasterDanceRepository(
            client: client,
            organizationID: organizationID
        )
        return WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: cacheDirectory,
            cacheKey: "\(organizationID.uuidString)-\(userID.uuidString)"
        )
    }
}

private final class InMemoryFirstAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let backing: any AuthLocalStorage
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    init(backing: any AuthLocalStorage) {
        self.backing = backing
    }

    func store(key: String, value: Data) throws {
        lock.withLock {
            values[key] = value
        }
        try backing.store(key: key, value: value)
    }

    func retrieve(key: String) throws -> Data? {
        if let value = lock.withLock({ values[key] }) {
            return value
        }

        let value = try backing.retrieve(key: key)
        if let value {
            lock.withLock {
                values[key] = value
            }
        }
        return value
    }

    func remove(key: String) throws {
        lock.withLock {
            values[key] = nil
        }
        try backing.remove(key: key)
    }
}

private final class VolatileAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func retrieve(key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = nil
    }
}
