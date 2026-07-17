import Foundation
import MasterDanceCore
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let repository: any MasterDanceRepository

    var terms: [Term] = []
    var categories: [CourseCategory] = []
    var ageGroups: [AgeGroup] = []
    var rooms: [Room] = []
    var instructors: [Instructor] = []
    var courses: [Course] = []
    var sessions: [ClassSession] = []
    var students: [Student] = []
    var guardians: [Guardian] = []
    var enrollments: [Enrollment] = []
    var attendance: [Attendance] = []
    var leaveRequests: [LeaveRequest] = []
    var contractConsents: [ContractConsent] = []
    var notifications: [NotificationRecord] = []
    var focusedSessionID: ClassSessionID?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    init(repository: any MasterDanceRepository) {
        self.repository = repository
    }

    func reload() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            terms = try await repository.listTerms().sorted { $0.startsOn > $1.startsOn }
            categories = try await repository.listCourseCategories().sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            ageGroups = try await repository.listAgeGroups().sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            rooms = try await repository.listRooms().sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            instructors = try await repository.listInstructors().sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
            courses = try await repository.listCourses(termID: nil).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            sessions = try await repository.listSessions(courseID: nil).sorted { $0.startsAt < $1.startsAt }
            students = try await repository.listStudents().sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
            guardians = try await repository.listGuardians(studentID: nil)
            enrollments = try await repository.listEnrollments(termID: nil, courseID: nil, studentID: nil)
            attendance = try await repository.listAttendance(sessionID: nil, studentID: nil)
            leaveRequests = try await repository.listLeaveRequests(sessionID: nil, studentID: nil)
            notifications = try await repository.listNotifications(recipientReference: nil)
            if let term = terms.first {
                contractConsents = try await repository.listContractConsents(termID: term.id, enrollmentID: nil)
            } else {
                contractConsents = []
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func course(id: CourseID) -> Course? {
        courses.first { $0.id == id }
    }

    func term(id: TermID) -> Term? {
        terms.first { $0.id == id }
    }

    func category(id: CourseCategoryID) -> CourseCategory? {
        categories.first { $0.id == id }
    }

    func ageGroup(id: AgeGroupID) -> AgeGroup? {
        ageGroups.first { $0.id == id }
    }

    func room(id: RoomID?) -> Room? {
        guard let id else { return nil }
        return rooms.first { $0.id == id }
    }

    func instructor(id: InstructorID?) -> Instructor? {
        guard let id else { return nil }
        return instructors.first { $0.id == id }
    }

    func student(id: StudentID) -> Student? {
        students.first { $0.id == id }
    }

    func session(id: ClassSessionID) -> ClassSession? {
        sessions.first { $0.id == id }
    }

    func effectiveRoom(for session: ClassSession) -> Room? {
        guard let course = course(id: session.courseID) else { return nil }
        return room(id: session.roomOverrideID ?? course.defaultRoomID)
    }

    func effectiveInstructor(for session: ClassSession) -> Instructor? {
        guard let course = course(id: session.courseID) else { return nil }
        return instructor(id: session.instructorOverrideID ?? course.defaultInstructorID)
    }

    func enrollments(for studentID: StudentID) -> [Enrollment] {
        enrollments.filter { $0.studentID == studentID && $0.status == .active }
    }

    func enrollments(forCourse courseID: CourseID) -> [Enrollment] {
        enrollments.filter { $0.courseID == courseID && $0.status == .active }
    }

    func sessions(forCourse courseID: CourseID) -> [ClassSession] {
        sessions.filter { $0.courseID == courseID }.sorted { $0.startsAt < $1.startsAt }
    }

    func createTerm(name: String, startsOn: Date, endsOn: Date) async throws {
        guard startsOn <= endsOn else { throw AppModelError.invalidTermRange }
        let term = Term(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startsOn: startsOn,
            endsOn: endsOn,
            status: .draft
        )
        try await repository.save(term: term)
        await reload()
    }

    func createCourse(from draft: CourseCreationDraft) async throws {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedName.isEmpty,
            let termID = draft.termID,
            let categoryID = draft.categoryID,
            let ageGroupID = draft.ageGroupID,
            let roomID = draft.roomID,
            let instructorID = draft.instructorID
        else {
            throw AppModelError.missingCourseFields
        }

        let course = Course(
            termID: termID,
            name: trimmedName,
            categoryID: categoryID,
            ageGroupID: ageGroupID,
            defaultRoomID: roomID,
            defaultInstructorID: instructorID,
            format: draft.format,
            notes: draft.notes.isEmpty ? nil : draft.notes
        )
        let plan = WeeklySessionPlan(
            courseID: course.id,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            weekday: draft.weekday,
            startTime: draft.startTime,
            endTime: draft.endTime,
            excludedDates: draft.excludedDates
        )
        let generatedSessions = try RecurringSessionBuilder.sessions(for: plan, calendar: .masterDance)

        try await repository.save(course: course)
        for session in generatedSessions {
            try await repository.save(session: session)
        }
        await reload()
    }

    func createReference(kind: ReferenceKind, name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        switch kind {
        case .category:
            try await repository.save(courseCategory: CourseCategory(name: trimmedName))
        case .ageGroup:
            try await repository.save(ageGroup: AgeGroup(name: trimmedName))
        case .room:
            try await repository.save(room: Room(name: trimmedName))
        case .instructor:
            try await repository.save(instructor: Instructor(displayName: trimmedName))
        }
        await reload()
    }

    func createStudent(displayName: String, kind: StudentKind, guardianName: String) async throws {
        let student = Student(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind
        )
        try await repository.save(student: student)

        let trimmedGuardian = guardianName.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == .child, !trimmedGuardian.isEmpty {
            try await repository.save(
                guardian: Guardian(displayName: trimmedGuardian, studentIDs: [student.id])
            )
        }
        await reload()
    }

    func enroll(studentID: StudentID, courseID: CourseID) async throws {
        guard let course = course(id: courseID) else {
            throw AppModelError.missingEnrollmentFields
        }
        if let existing = enrollments.first(where: { $0.studentID == studentID && $0.courseID == courseID }) {
            var restored = existing
            restored.status = .active
            try await repository.save(enrollment: restored)
        } else {
            try await repository.save(
                enrollment: Enrollment(
                    termID: course.termID,
                    courseID: courseID,
                    studentID: studentID,
                    enrolledAt: Date()
                )
            )
        }
        await reload()
    }

    func removeEnrollment(id: EnrollmentID) async throws {
        try await repository.deleteEnrollment(id: id)
        await reload()
    }

    func recordAttendance(sessionID: ClassSessionID, studentID: StudentID, status: AttendanceStatus) async throws {
        let enrollmentID = session(id: sessionID).flatMap { session in
            enrollments.first { $0.courseID == session.courseID && $0.studentID == studentID }?.id
        }
        if let existing = attendance.first(where: { $0.sessionID == sessionID && $0.studentID == studentID }) {
            var updated = existing
            updated.status = status
            updated.recordedAt = Date()
            try await repository.save(attendance: updated)
        } else {
            try await repository.save(
                attendance: Attendance(
                    sessionID: sessionID,
                    studentID: studentID,
                    enrollmentID: enrollmentID,
                    status: status,
                    recordedAt: Date()
                )
            )
        }
        await reload()
    }

    func resolveLeaveRequest(id: LeaveRequestID, status: LeaveRequestStatus) async throws {
        guard status == .approved || status == .denied else { return }
        guard var request = leaveRequests.first(where: { $0.id == id }) else { return }
        request.status = status
        request.resolvedAt = Date()
        try await repository.save(leaveRequest: request)
        await reload()
    }
}
