import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Local-first repository")
struct WriteBehindMasterDanceRepositoryTests {
    @Test("Attendance is durable locally before cloud synchronization")
    func attendancePersistsBeforeSync() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let remote = PreviewMasterDanceStore()
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "organization-user"
        )
        _ = try await repository.listTerms()

        let record = Attendance(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            status: .present,
            recordedAt: Date(timeIntervalSince1970: 1_000)
        )
        try await repository.save(attendance: record)

        #expect(await repository.pendingMutationCount() == 1)
        #expect(try await repository.listAttendance(sessionID: nil, studentID: nil) == [record])
        #expect(await remote.listAttendance(sessionID: nil, studentID: nil).isEmpty)

        let restored = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "organization-user"
        )
        #expect(await restored.pendingMutationCount() == 1)
        #expect(try await restored.listAttendance(sessionID: nil, studentID: nil) == [record])

        #expect(try await restored.synchronizeIfNeeded() == 1)
        #expect(await restored.pendingMutationCount() == 0)
        #expect(await remote.listAttendance(sessionID: nil, studentID: nil) == [record])
    }

    @Test("Repeated attendance changes coalesce to the latest value")
    func repeatedAttendanceCoalesces() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let remote = PreviewMasterDanceStore()
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "coalescing"
        )
        _ = try await repository.listTerms()

        var record = Attendance(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            status: .present,
            recordedAt: Date(timeIntervalSince1970: 1_000)
        )
        try await repository.save(attendance: record)
        record.status = .absent
        record.recordedAt = Date(timeIntervalSince1970: 2_000)
        try await repository.save(attendance: record)

        #expect(await repository.pendingMutationCount() == 1)
        #expect(try await repository.synchronizeIfNeeded() == 1)
        #expect(await remote.listAttendance(sessionID: nil, studentID: nil) == [record])
        #expect(try await repository.synchronizeIfNeeded() == 0)
    }

    @Test("Cancelling attendance restores unrecorded state before synchronization")
    func cancellingAttendanceBeforeSync() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let remote = PreviewMasterDanceStore()
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "attendance-cancellation"
        )
        _ = try await repository.listTerms()

        let record = Attendance(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            status: .present,
            recordedAt: Date(timeIntervalSince1970: 1_000)
        )
        try await repository.save(attendance: record)
        try await repository.deleteAttendance(id: record.id)

        #expect(await repository.pendingMutationCount() == 1)
        #expect(try await repository.listAttendance(sessionID: nil, studentID: nil).isEmpty)
        #expect(try await repository.synchronizeIfNeeded() == 1)
        #expect(await remote.listAttendance(sessionID: nil, studentID: nil).isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("master-dance-write-behind-\(UUID().uuidString)", isDirectory: true)
    }
}
