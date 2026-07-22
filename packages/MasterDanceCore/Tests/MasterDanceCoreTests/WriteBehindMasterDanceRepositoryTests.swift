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

    @Test("Deleting an administrator leave request is immediate and synchronizes later")
    func deletingLeaveRequestBeforeSync() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let request = LeaveRequest(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            source: .administrator,
            submittedAt: Date(timeIntervalSince1970: 1_000)
        )
        let remote = PreviewMasterDanceStore(data: PreviewData(leaveRequests: [request]))
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "leave-request-deletion"
        )
        _ = try await repository.listTerms()

        try await repository.deleteLeaveRequest(id: request.id)

        #expect(await repository.pendingMutationCount() == 1)
        #expect(try await repository.listLeaveRequests(sessionID: nil, studentID: nil).isEmpty)
        #expect(await remote.listLeaveRequests(sessionID: nil, studentID: nil) == [request])

        let restored = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "leave-request-deletion"
        )
        #expect(await restored.pendingMutationCount() == 1)
        #expect(try await restored.listLeaveRequests(sessionID: nil, studentID: nil).isEmpty)

        #expect(try await restored.synchronizeIfNeeded() == 1)
        #expect(await remote.listLeaveRequests(sessionID: nil, studentID: nil).isEmpty)
    }

    @Test("Guarded family deletion is confirmed remotely before local removal")
    func familyDeletionIsRemoteFirst() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let guardian = Guardian(displayName: "Temporary Family")
        let student = Student(guardianID: guardian.id, displayName: "Student", kind: .child)
        let remote = PreviewMasterDanceStore(
            data: PreviewData(students: [student], guardians: [guardian])
        )
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "family-deletion"
        )
        _ = try await repository.listGuardians(studentID: nil)

        try await repository.deleteGuardian(id: guardian.id)

        #expect(await repository.pendingMutationCount() == 0)
        #expect(try await repository.listGuardians(studentID: nil).isEmpty)
        #expect(try await repository.listStudents().isEmpty)
        #expect(try await remote.listGuardians(studentID: nil).isEmpty)
        #expect(try await remote.listStudents().isEmpty)
    }

    @Test("Orphaned session writes are discarded instead of blocking synchronization")
    func orphanedSessionWritesAreDiscarded() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let remote = PreviewMasterDanceStore()
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "orphaned-session"
        )
        _ = try await repository.listTerms()

        let orphanedSession = ClassSession(
            courseID: CourseID(),
            startsAt: Date(timeIntervalSince1970: 1_000),
            endsAt: Date(timeIntervalSince1970: 4_600)
        )
        try await repository.save(session: orphanedSession)

        #expect(await repository.pendingMutationCount() == 0)
        #expect(try await repository.synchronizeIfNeeded() == 0)
        #expect(await remote.listSessions(courseID: nil).isEmpty)
    }

    @Test("Deleting a course removes queued writes for its sessions")
    func deletingCourseRemovesSessionWrites() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let term = Term(
            name: "2026 Fall",
            startsOn: Date(timeIntervalSince1970: 1_000),
            endsOn: Date(timeIntervalSince1970: 1_000_000),
            status: .open
        )
        let course = Course(
            termID: term.id,
            name: "Ballet",
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: RoomID(),
            defaultInstructorID: InstructorID(),
            courseTypeID: CourseTypeID(),
            format: .group
        )
        var session = ClassSession(
            courseID: course.id,
            startsAt: Date(timeIntervalSince1970: 10_000),
            endsAt: Date(timeIntervalSince1970: 13_600)
        )
        let remote = PreviewMasterDanceStore(
            data: PreviewData(terms: [term], courses: [course], sessions: [session])
        )
        let repository = WriteBehindMasterDanceRepository(
            remote: remote,
            cacheDirectory: directory,
            cacheKey: "course-session-deletion"
        )
        _ = try await repository.listTerms()

        session.endsAt = Date(timeIntervalSince1970: 14_200)
        try await repository.save(session: session)
        try await repository.deleteCourse(id: course.id)

        #expect(await repository.pendingMutationCount() == 1)
        #expect(try await repository.synchronizeIfNeeded() == 1)
        #expect(await remote.listCourses(termID: nil).isEmpty)
        #expect(await remote.listSessions(courseID: nil).isEmpty)
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
