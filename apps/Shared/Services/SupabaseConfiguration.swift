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
        return SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
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
