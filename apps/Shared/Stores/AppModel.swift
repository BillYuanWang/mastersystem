import Foundation
import MasterDanceCore
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let repository: any MasterDanceRepository

    var terms: [Term] = []
    var termHolidays: [TermHoliday] = []
    private var courseCategories: [CourseCategory] = []
    var courseTypes: [CourseType] = []
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
    var contractDocuments: [ContractDocument] = []
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
            termHolidays = try await repository.listTermHolidays(termID: nil).sorted { $0.startsOn < $1.startsOn }
            courseCategories = try await repository.listCourseCategories().sorted {
                $0.name.localizedCompare($1.name) == .orderedAscending
            }
            courseTypes = try await repository.listCourseTypes().sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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
            contractDocuments = try await repository.listContractDocuments(termID: nil)
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

    func courseType(id: CourseTypeID) -> CourseType? {
        courseTypes.first { $0.id == id }
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

    func guardian(id: GuardianID) -> Guardian? {
        guardians.first { $0.id == id }
    }

    func students(for guardianID: GuardianID) -> [Student] {
        return students
            .filter { $0.guardianID == guardianID }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    var unassignedStudents: [Student] {
        []
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

    func saveTerm(_ term: Term) async throws {
        guard term.startsOn <= term.endsOn else { throw AppModelError.invalidTermRange }
        guard termHolidays.filter({ $0.termID == term.id }).allSatisfy({
            $0.startsOn >= term.startsOn && $0.endsOn <= term.endsOn
        }) else {
            throw AppModelError.holidayOutsideTerm
        }
        try await repository.save(term: term)
        await reload()
    }

    func deleteTerm(id: TermID) async throws {
        try await repository.deleteTerm(id: id)
        await reload()
    }

    func saveTermHoliday(_ holiday: TermHoliday) async throws {
        guard holiday.startsOn <= holiday.endsOn else { throw AppModelError.invalidTermRange }
        guard let term = term(id: holiday.termID),
              holiday.startsOn >= term.startsOn,
              holiday.endsOn <= term.endsOn else {
            throw AppModelError.holidayOutsideTerm
        }
        try await repository.save(termHoliday: holiday)
        await reload()
    }

    func deleteTermHoliday(id: TermHolidayID) async throws {
        try await repository.deleteTermHoliday(id: id)
        await reload()
    }

    func saveCourseType(_ courseType: CourseType) async throws {
        try await repository.save(courseType: courseType)
        await reload()
    }

    func deleteCourseType(id: CourseTypeID) async throws {
        try await repository.deleteCourseType(id: id)
        await reload()
    }

    func saveAgeGroup(_ ageGroup: AgeGroup) async throws {
        try await repository.save(ageGroup: ageGroup)
        await reload()
    }

    func deleteAgeGroup(id: AgeGroupID) async throws {
        try await repository.deleteAgeGroup(id: id)
        await reload()
    }

    func saveRoom(_ room: Room) async throws {
        try await repository.save(room: room)
        await reload()
    }

    func deleteRoom(id: RoomID) async throws {
        try await repository.deleteRoom(id: id)
        await reload()
    }

    func saveInstructor(_ instructor: Instructor) async throws {
        try await repository.save(instructor: instructor)
        await reload()
    }

    func deleteInstructor(id: InstructorID) async throws {
        try await repository.deleteInstructor(id: id)
        await reload()
    }

    func saveCourse(_ course: Course) async throws {
        guard let type = courseType(id: course.courseTypeID) else {
            throw AppModelError.missingCourseFields
        }
        var updated = course
        updated.format = type.isPrivate ? .privateLesson : .group
        try await repository.save(course: updated)
        await reload()
    }

    func deleteCourse(id: CourseID) async throws {
        try await repository.deleteCourse(id: id)
        await reload()
    }

    func createCourse(from draft: CourseCreationDraft) async throws {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedName.isEmpty,
            let termID = draft.termID,
            let ageGroupID = draft.ageGroupID,
            let roomID = draft.roomID,
            let instructorID = draft.instructorID,
            let courseTypeID = draft.courseTypeID,
            let selectedCourseType = courseType(id: courseTypeID)
        else {
            throw AppModelError.missingCourseFields
        }
        let categoryID = try await hiddenCourseCategoryID()

        let course = Course(
            termID: termID,
            name: trimmedName,
            categoryID: categoryID,
            ageGroupID: ageGroupID,
            defaultRoomID: roomID,
            defaultInstructorID: instructorID,
            courseTypeID: courseTypeID,
            format: selectedCourseType.isPrivate ? .privateLesson : .group,
            notes: draft.notes.isEmpty ? nil : draft.notes
        )
        let holidayDates = termHolidays
            .filter { $0.termID == termID }
            .reduce(into: Set<Date>()) { dates, holiday in
                dates.formUnion(calendarDays(from: holiday.startsOn, through: holiday.endsOn))
            }
        let plan = WeeklySessionPlan(
            courseID: course.id,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            weekday: draft.weekday,
            startTime: draft.startTime,
            endTime: draft.endTime,
            excludedDates: draft.excludedDates.union(holidayDates)
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
        case .ageGroup:
            try await repository.save(ageGroup: AgeGroup(name: trimmedName))
        case .room:
            try await repository.save(room: Room(name: trimmedName))
        case .instructor:
            try await repository.save(instructor: Instructor(displayName: trimmedName))
        }
        await reload()
    }

    private func hiddenCourseCategoryID() async throws -> CourseCategoryID {
        if let existing = courseCategories.first(where: \.isActive) ?? courseCategories.first {
            return existing.id
        }

        let fallback = CourseCategory(name: "系统默认")
        try await repository.save(courseCategory: fallback)
        courseCategories.append(fallback)
        return fallback.id
    }

    func createGuardian(
        displayName: String,
        email: String,
        phone: String
    ) async throws -> GuardianLinkCode {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppModelError.missingGuardianName
        }
        if !trimmedEmail.isEmpty, !trimmedEmail.contains("@") {
            throw AppModelError.invalidGuardianEmail
        }

        let guardian = Guardian(
            displayName: trimmedName,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone
        )
        try await repository.save(guardian: guardian)

        do {
            let code = try await repository.issueGuardianLinkCode(guardianID: guardian.id)
            await reload()
            return code
        } catch {
            await reload()
            throw error
        }
    }

    func createStudent(
        displayName: String,
        legalName: String,
        kind: StudentKind,
        guardianID: GuardianID
    ) async throws {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLegalName = legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppModelError.missingStudentName
        }
        let student = Student(
            guardianID: guardianID,
            displayName: trimmedName,
            legalName: trimmedLegalName.isEmpty ? nil : trimmedLegalName,
            kind: kind
        )
        _ = try await repository.create(student: student, for: guardianID)
        await reload()
    }

    func link(studentID: StudentID, to guardianID: GuardianID) async throws {
        try await repository.link(studentID: studentID, to: guardianID)
        await reload()
    }

    func issueGuardianLinkCode(guardianID: GuardianID) async throws -> GuardianLinkCode {
        let code = try await repository.issueGuardianLinkCode(guardianID: guardianID)
        await reload()
        return code
    }

    func saveGuardian(_ guardian: Guardian) async throws {
        let name = guardian.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppModelError.missingGuardianName }
        var updated = guardian
        updated.displayName = name
        try await repository.save(guardian: updated)
        await reload()
    }

    func deleteGuardian(id: GuardianID) async throws {
        try await repository.deleteGuardian(id: id)
        await reload()
    }

    func saveStudent(_ student: Student) async throws {
        let name = student.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppModelError.missingStudentName }
        var updated = student
        updated.displayName = name
        try await repository.save(student: updated)
        await reload()
    }

    func deleteStudent(id: StudentID) async throws {
        try await repository.deleteStudent(id: id)
        await reload()
    }

    func saveContractDocument(_ document: ContractDocument, fileData: Data?) async throws {
        _ = try await repository.save(contractDocument: document, fileData: fileData)
        await reload()
    }

    func deleteContractDocument(_ document: ContractDocument) async throws {
        try await repository.deleteContractDocument(id: document.id, storagePath: document.storagePath)
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

    private func calendarDays(from startsOn: Date, through endsOn: Date) -> Set<Date> {
        let calendar = Calendar.masterDance
        var date = calendar.startOfDay(for: startsOn)
        let end = calendar.startOfDay(for: endsOn)
        var dates: Set<Date> = []
        while date <= end {
            dates.insert(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return dates
    }
}
