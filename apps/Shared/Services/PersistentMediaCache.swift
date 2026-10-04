import CryptoKit
import Foundation

struct PersistentMediaCacheLookup: Sendable {
    let data: Data
    let storedAt: Date
    let isFresh: Bool
}

enum PersistentMediaCacheError: Error {
    case emptyData
}

actor PersistentMediaCache {
    static let shared = PersistentMediaCache()
    static let defaultRetention: TimeInterval = 180 * 24 * 60 * 60

    private let directoryURL: URL
    private let retention: TimeInterval
    private var inFlightLoads: [String: Task<Data, Error>] = [:]

    init(
        directoryURL: URL = PersistentMediaCache.defaultDirectoryURL,
        retention: TimeInterval = PersistentMediaCache.defaultRetention
    ) {
        self.directoryURL = directoryURL
        self.retention = retention
    }

    static func resourceKey(
        namespace: String,
        storagePath: String,
        revision: Date?
    ) -> String {
        let revisionMilliseconds = Int64((revision?.timeIntervalSince1970 ?? 0) * 1_000)
        return "\(namespace)|\(storagePath)|\(revisionMilliseconds)"
    }

    func lookup(for key: String, now: Date = Date()) -> PersistentMediaCacheLookup? {
        let fileURL = fileURL(for: key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        let storedAt = attributes[.modificationDate] as? Date ?? .distantPast
        return PersistentMediaCacheLookup(
            data: data,
            storedAt: storedAt,
            isFresh: now.timeIntervalSince(storedAt) <= retention
        )
    }

    func refresh(
        key: String,
        now: Date = Date(),
        loader: @escaping @Sendable () async throws -> Data
    ) async throws -> Data {
        if let inFlight = inFlightLoads[key] {
            return try await inFlight.value
        }

        let load = Task<Data, Error> {
            let data = try await loader()
            guard !data.isEmpty else { throw PersistentMediaCacheError.emptyData }
            return data
        }
        inFlightLoads[key] = load

        do {
            let data = try await load.value
            try store(data, for: key, now: now)
            inFlightLoads.removeValue(forKey: key)
            return data
        } catch {
            inFlightLoads.removeValue(forKey: key)
            throw error
        }
    }

    func store(_ data: Data, for key: String, now: Date = Date()) throws {
        guard !data.isEmpty else { throw PersistentMediaCacheError.emptyData }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let destination = fileURL(for: key)
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: destination.path
        )
    }

    func pruneExpired(
        keeping retainedKeys: Set<String> = [],
        now: Date = Date()
    ) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let retainedFilenames = Set(retainedKeys.map(filename(for:)))
        for file in files where !retainedFilenames.contains(file.lastPathComponent) {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            let storedAt = values?.contentModificationDate ?? .distantPast
            guard now.timeIntervalSince(storedAt) > retention else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(filename(for: key), isDirectory: false)
    }

    private func filename(for key: String) -> String {
        SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static var defaultDirectoryURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Master Dance", isDirectory: true)
            .appendingPathComponent("Media Cache", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }
}
