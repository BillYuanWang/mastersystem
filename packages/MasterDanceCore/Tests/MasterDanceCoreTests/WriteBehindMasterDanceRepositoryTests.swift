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

    @Test("Remote changes refresh the local snapshot only after the sequence advances")
    func remoteChangeSequenceControlsRefresh() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let guardianID = GuardianID()
        let initialGuardian = Guardian(id: guardianID, displayName: "测试监护人")
        let remote = PreviewMasterDanceStore(
            data: PreviewData(guardians: [initialGuardian])
        )
        let sequence = RemoteChangeSequence(1)
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "remote-change-sequence",
            latestRemoteChangeSequence: {
                await sequence.current()
            }
        )

        #expect(try await repository.listGuardians(studentID: nil) == [initialGuardian])

        var linkedGuardian = initialGuardian
        linkedGuardian.profileUserID = UUID()
        await remote.save(guardian: linkedGuardian)

        #expect(try await repository.refreshFromRemoteIfChanged() == false)
        #expect(try await repository.listGuardians(studentID: nil) == [initialGuardian])

        await sequence.advance()
        #expect(try await repository.refreshFromRemoteIfChanged())
        #expect(try await repository.listGuardians(studentID: nil) == [linkedGuardian])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("master-dance-write-behind-\(UUID().uuidString)", isDirectory: true)
    }
}

private actor RemoteChangeSequence {
    private var value: Int64

    init(_ value: Int64) {
        self.value = value
    }

    func current() -> Int64 {
        value
    }

    func advance() {
        value += 1
    }
}
