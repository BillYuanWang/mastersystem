#if os(macOS)
import Foundation
import Testing
@testable import MasterDanceAdmin

@Suite("Persistent media cache")
struct PersistentMediaCacheTests {
    @Test("A downloaded image survives a new cache instance")
    func persistsAcrossLaunches() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storedAt = Date(timeIntervalSince1970: 1_000)
        let key = PersistentMediaCache.resourceKey(
            namespace: "news",
            storagePath: "organization/article/cover.jpeg",
            revision: storedAt
        )
        let expected = Data([1, 2, 3, 4])

        let writer = PersistentMediaCache(directoryURL: directory, retention: 100)
        try await writer.store(expected, for: key, now: storedAt)

        let reader = PersistentMediaCache(directoryURL: directory, retention: 100)
        let hit = await reader.lookup(for: key, now: storedAt.addingTimeInterval(99))

        #expect(hit?.data == expected)
        #expect(hit?.isFresh == true)
    }

    @Test("The hard-drive copy remains the source of truth")
    func readsCurrentDiskCopyInsteadOfRetainingImageBytesInMemory() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PersistentMediaCache(directoryURL: directory)
        let key = "news|disk-source-of-truth"

        try await cache.store(Data([1, 2, 3]), for: key)
        let file = try #require(
            FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).first
        )
        try Data([9, 8, 7]).write(to: file, options: .atomic)

        let hit = await cache.lookup(for: key)

        #expect(hit?.data == Data([9, 8, 7]))
    }

    @Test("Expired media remains available while a refresh is attempted")
    func returnsStaleMedia() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PersistentMediaCache(directoryURL: directory, retention: 100)
        let storedAt = Date(timeIntervalSince1970: 2_000)
        let key = "advertisement|slot-1|revision-1"
        let expected = Data([5, 6, 7])

        try await cache.store(expected, for: key, now: storedAt)
        let hit = await cache.lookup(for: key, now: storedAt.addingTimeInterval(101))

        #expect(hit?.data == expected)
        #expect(hit?.isFresh == false)
    }

    @Test("A new cloud revision cannot reuse the previous image")
    func isolatesMediaRevisions() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PersistentMediaCache(directoryURL: directory)
        let path = "organization/advertisement/thumbnail.jpeg"
        let oldKey = PersistentMediaCache.resourceKey(
            namespace: "advertisement",
            storagePath: path,
            revision: Date(timeIntervalSince1970: 3_000)
        )
        let newKey = PersistentMediaCache.resourceKey(
            namespace: "advertisement",
            storagePath: path,
            revision: Date(timeIntervalSince1970: 4_000)
        )

        try await cache.store(Data([8, 9]), for: oldKey)

        #expect(await cache.lookup(for: oldKey) != nil)
        #expect(await cache.lookup(for: newKey) == nil)
    }

    @Test("Concurrent views share one cloud download")
    func coalescesConcurrentRefreshes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PersistentMediaCache(directoryURL: directory)
        let probe = MediaLoadProbe()

        async let first = cache.refresh(key: "shared") {
            try await probe.load()
        }
        async let second = cache.refresh(key: "shared") {
            try await probe.load()
        }
        let values = try await (first, second)

        #expect(values.0 == Data([10, 11]))
        #expect(values.1 == Data([10, 11]))
        #expect(await probe.loadCount == 1)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("persistent-media-cache-\(UUID().uuidString)", isDirectory: true)
    }
}

private actor MediaLoadProbe {
    private(set) var loadCount = 0

    func load() async throws -> Data {
        loadCount += 1
        try await Task.sleep(nanoseconds: 25_000_000)
        return Data([10, 11])
    }
}
#endif
