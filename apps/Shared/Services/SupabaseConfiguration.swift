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
        makeSessionClient(persistSession: true).client
    }

    func makeEphemeralAuthClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: VolatileAuthStorage(),
                    autoRefreshToken: false
                )
            )
        )
    }

    func makeSessionClient(persistSession: Bool) -> ConfiguredSessionClient {
        let backing: any AuthLocalStorage
        if ProcessInfo.processInfo.environment["MASTER_DANCE_VOLATILE_AUTH"] == "1" {
            backing = VolatileAuthStorage()
        } else if usesProtectedFileAuthStorage {
            backing = ProtectedFileAuthStorage()
        } else {
            backing = KeychainLocalStorage()
        }
        let authStorage = SessionAwareAuthStorage(
            backing: backing,
            persistsSession: persistSession
        )
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: authStorage)
            )
        )
        return ConfiguredSessionClient(client: client, authStorage: authStorage)
    }

    private var usesProtectedFileAuthStorage: Bool {
#if os(macOS)
        ProcessInfo.processInfo.environment["MASTER_DANCE_FILE_AUTH"] == "1"
            || (Bundle.main.object(forInfoDictionaryKey: "MDUseProtectedFileAuthStorage") as? Bool) == true
#else
        false
#endif
    }
}

struct ConfiguredSessionClient {
    let client: SupabaseClient
    let authStorage: SessionAwareAuthStorage
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
            cacheKey: "\(organizationID.uuidString)-\(userID.uuidString)",
            latestRemoteChangeSequence: {
                try await remote.latestRemoteChangeSequence()
            }
        )
    }
}

final class SessionAwareAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private static let sessionKeys = ["supabase.auth.token", "supabase.session"]

    private let backing: any AuthLocalStorage
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    private var persistsSession: Bool

    init(backing: any AuthLocalStorage, persistsSession: Bool) {
        self.backing = backing
        self.persistsSession = persistsSession
        if !persistsSession {
            Self.sessionKeys.forEach { try? backing.remove(key: $0) }
        }
    }

    func setSessionPersistenceEnabled(_ isEnabled: Bool) {
        let sessionValues = lock.withLock {
            persistsSession = isEnabled
            return Self.sessionKeys.compactMap { key in
                values[key].map { (key, $0) }
            }
        }

        if isEnabled {
            sessionValues.forEach { entry in
                try? backing.store(key: entry.0, value: entry.1)
            }
        } else {
            Self.sessionKeys.forEach { try? backing.remove(key: $0) }
        }
    }

    func store(key: String, value: Data) throws {
        let shouldPersist = lock.withLock {
            values[key] = value
            return persistsSession || !Self.sessionKeys.contains(key)
        }
        if shouldPersist {
            try backing.store(key: key, value: value)
        } else {
            try? backing.remove(key: key)
        }
    }

    func retrieve(key: String) throws -> Data? {
        if let value = lock.withLock({ values[key] }) {
            return value
        }

        let shouldPersist = lock.withLock {
            persistsSession || !Self.sessionKeys.contains(key)
        }
        guard shouldPersist else {
            try? backing.remove(key: key)
            return nil
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

final class ProtectedFileAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private let fileManager: FileManager

    init(
        fileURL: URL = ProtectedFileAuthStorage.defaultFileURL,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func store(key: String, value: Data) throws {
        try lock.withLock {
            var values = try loadValues()
            values[key] = value
            try saveValues(values)
        }
    }

    func retrieve(key: String) throws -> Data? {
        try lock.withLock {
            try loadValues()[key]
        }
    }

    func remove(key: String) throws {
        try lock.withLock {
            var values = try loadValues()
            values[key] = nil
            try saveValues(values)
        }
    }

    private func loadValues() throws -> [String: Data] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: Data].self, from: data)
    }

    private func saveValues(_ values: [String: Data]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        if values.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        let data = try JSONEncoder().encode(values)
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static var defaultFileURL: URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("Master Dance", isDirectory: true)
            .appendingPathComponent("Local Auth", isDirectory: true)
            .appendingPathComponent("session.json")
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
