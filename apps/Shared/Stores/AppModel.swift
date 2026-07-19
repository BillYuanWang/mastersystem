import Foundation
import MasterDanceCore
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let repository: any MasterDanceRepository
    @ObservationIgnored private let referenceOrderStore = ReferenceOrderStore()
    @ObservationIgnored private var pendingBackgroundOperations: [PendingBackgroundOperation] = []
    @ObservationIgnored private var pendingCloudOperations: [PendingCloudOperation] = []
    @ObservationIgnored private var syncNoticeGeneration = UUID()

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
    var backgroundSync = BackgroundSyncPresentation()
    var cloudActivity = CloudActivityPresentation()
    var availableGuardianLinkCodes: [GuardianLinkCode] = []
    var focusedSessionID: ClassSessionID?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    init(repository: any MasterDanceRepository) {
        self.repository = repository
    }

    func performBackgroundOperation(
        label: String,
        successMessage: String,
        completion: (@MainActor (Result<Void, Error>) -> Void)? = nil,
        operation: @escaping @MainActor () async throws -> Void
    ) {
        let id = UUID()
        pendingBackgroundOperations.append(PendingBackgroundOperation(id: id, label: label))
        syncNoticeGeneration = UUID()
        backgroundSync.notice = nil
        refreshBackgroundSyncActivity()

        Task { @MainActor in
            do {
                try await operation()
                completeBackgroundOperation(id: id, successMessage: successMessage, error: nil)
                completion?(.success(()))
            } catch {
                completeBackgroundOperation(id: id, successMessage: successMessage, error: error)
                completion?(.failure(error))
            }
        }
    }

    func dismissBackgroundSyncNotice() {
        syncNoticeGeneration = UUID()
        backgroundSync.notice = nil
    }

    func retainGuardianLinkCode(_ code: GuardianLinkCode) {
        availableGuardianLinkCodes.append(code)
    }

    func clearGuardianLinkCode() {
        guard !availableGuardianLinkCodes.isEmpty else { return }
        availableGuardianLinkCodes.removeFirst()
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
            courseTypes = referenceOrderStore.apply(
                try await repository.listCourseTypes().sorted { $0.name.localizedCompare($1.name) == .orderedAscending },
                key: .courseTypes,
                id: { $0.id.description }
            )
            ageGroups = referenceOrderStore.apply(
                try await repository.listAgeGroups().sorted { $0.name.localizedCompare($1.name) == .orderedAscending },
                key: .ageGroups,
                id: { $0.id.description }
            )
            rooms = referenceOrderStore.apply(
                try await repository.listRooms().sorted { $0.name.localizedCompare($1.name) == .orderedAscending },
                key: .rooms,
                id: { $0.id.description }
            )
            instructors = referenceOrderStore.apply(
                try await repository.listInstructors().sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending },
                key: .instructors,
                id: { $0.id.description }
            )
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
        try await withCloudActivity(label: "创建学期") {
            try await repository.save(term: term)
            await reload()
        }
    }

    func saveTerm(_ term: Term) async throws {
        guard term.startsOn <= term.endsOn else { throw AppModelError.invalidTermRange }
        guard termHolidays.filter({ $0.termID == term.id }).allSatisfy({
            $0.startsOn >= term.startsOn && $0.endsOn <= term.endsOn
        }) else {
            throw AppModelError.holidayOutsideTerm
        }
        try await withCloudActivity(label: "保存学期") {
            try await repository.save(term: term)
            await reload()
        }
    }

    func deleteTerm(id: TermID) async throws {
        try await withCloudActivity(label: "删除学期") {
            try await repository.deleteTerm(id: id)
            await reload()
        }
    }

    func saveTermHoliday(_ holiday: TermHoliday) async throws {
        guard holiday.startsOn <= holiday.endsOn else { throw AppModelError.invalidTermRange }
        guard let term = term(id: holiday.termID),
              holiday.startsOn >= term.startsOn,
              holiday.endsOn <= term.endsOn else {
            throw AppModelError.holidayOutsideTerm
        }
        try await withCloudActivity(label: "保存假期") {
            try await repository.save(termHoliday: holiday)
            await reload()
        }
    }

    func deleteTermHoliday(id: TermHolidayID) async throws {
        try await withCloudActivity(label: "删除假期") {
            try await repository.deleteTermHoliday(id: id)
            await reload()
        }
    }

    func saveCourseType(_ courseType: CourseType) async throws {
        try await withCloudActivity(label: "保存课程种类") {
            try await repository.save(courseType: courseType)
            await reload()
        }
    }

    func deleteCourseType(id: CourseTypeID) async throws {
        try await withCloudActivity(label: "删除课程种类") {
            try await repository.deleteCourseType(id: id)
            await reload()
        }
    }

    func saveAgeGroup(_ ageGroup: AgeGroup) async throws {
        try await withCloudActivity(label: "保存年龄段") {
            try await repository.save(ageGroup: ageGroup)
            await reload()
        }
    }

    func deleteAgeGroup(id: AgeGroupID) async throws {
        try await withCloudActivity(label: "删除年龄段") {
            try await repository.deleteAgeGroup(id: id)
            await reload()
        }
    }

    func saveRoom(_ room: Room) async throws {
        try await withCloudActivity(label: "保存教室") {
            try await repository.save(room: room)
            await reload()
        }
    }

    func deleteRoom(id: RoomID) async throws {
        try await withCloudActivity(label: "删除教室") {
            try await repository.deleteRoom(id: id)
            await reload()
        }
    }

    func saveInstructor(_ instructor: Instructor) async throws {
        try await withCloudActivity(label: "保存授课老师") {
            try await repository.save(instructor: instructor)
            await reload()
        }
    }

    func deleteInstructor(id: InstructorID) async throws {
        try await withCloudActivity(label: "删除授课老师") {
            try await repository.deleteInstructor(id: id)
            await reload()
        }
    }

    func moveCourseType(_ sourceID: CourseTypeID, to targetID: CourseTypeID) {
        courseTypes = moving(courseTypes, sourceID: sourceID, to: targetID)
        referenceOrderStore.save(courseTypes, key: .courseTypes, id: { $0.id.description })
    }

    func moveAgeGroup(_ sourceID: AgeGroupID, to targetID: AgeGroupID) {
        ageGroups = moving(ageGroups, sourceID: sourceID, to: targetID)
        referenceOrderStore.save(ageGroups, key: .ageGroups, id: { $0.id.description })
    }

    func moveRoom(_ sourceID: RoomID, to targetID: RoomID) {
        rooms = moving(rooms, sourceID: sourceID, to: targetID)
        referenceOrderStore.save(rooms, key: .rooms, id: { $0.id.description })
    }

    func moveInstructor(_ sourceID: InstructorID, to targetID: InstructorID) {
        instructors = moving(instructors, sourceID: sourceID, to: targetID)
        referenceOrderStore.save(instructors, key: .instructors, id: { $0.id.description })
    }

    func saveCourse(_ course: Course) async throws {
        guard let type = courseType(id: course.courseTypeID) else {
            throw AppModelError.missingCourseFields
        }
        var updated = course
        updated.format = type.isPrivate ? .privateLesson : .group
        try await withCloudActivity(label: "保存课程") {
            try await repository.save(course: updated)
            await reload()
        }
    }

    func deleteCourse(id: CourseID) async throws {
        try await withCloudActivity(label: "删除课程") {
            try await repository.deleteCourse(id: id)
            await reload()
        }
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
        try await withCloudActivity(label: "创建课程") {
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
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                isActive: draft.isActive
            )
            let generatedSessions = try generatedSessions(for: course.id, termID: termID, draft: draft)

            try await repository.save(course: course)
            for session in generatedSessions {
                try await repository.save(session: session)
            }
            await reload()
        }
    }

    func updateCourse(_ original: Course, from draft: CourseCreationDraft) async throws {
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

        if original.termID != termID, enrollments.contains(where: { $0.courseID == original.id }) {
            throw AppModelError.courseTermHasEnrollments
        }

        var updated = original
        updated.termID = termID
        updated.name = trimmedName
        updated.ageGroupID = ageGroupID
        updated.defaultRoomID = roomID
        updated.defaultInstructorID = instructorID
        updated.courseTypeID = courseTypeID
        updated.format = selectedCourseType.isPrivate ? .privateLesson : .group
        updated.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updated.isActive = draft.isActive

        let existingSessions = sessions(forCourse: original.id)
        let replacementSessions = try generatedSessions(for: original.id, termID: termID, draft: draft)
        let scheduleChanged = !sameSchedule(existingSessions, replacementSessions)
        if scheduleChanged {
            let existingSessionIDs = Set(existingSessions.map(\.id))
            let hasAttendance = attendance.contains { existingSessionIDs.contains($0.sessionID) }
            let hasLeaveRequests = leaveRequests.contains { existingSessionIDs.contains($0.sessionID) }
            guard !hasAttendance, !hasLeaveRequests else {
                throw AppModelError.courseScheduleHasRecords
            }
        }

        try await withCloudActivity(label: "更新课程") {
            try await repository.save(course: updated)
            if scheduleChanged {
                for session in existingSessions {
                    try await repository.deleteSession(id: session.id)
                }
                for session in replacementSessions {
                    try await repository.save(session: session)
                }
            }
            await reload()
        }
    }

    func createReference(kind: ReferenceKind, name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        try await withCloudActivity(label: "创建\(kind.title)") {
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
        guard !trimmedName.isEmpty else {
            throw AppModelError.missingGuardianName
        }
        let contact = try normalizedGuardianContact(email: email, phone: phone)

        let guardian = Guardian(
            displayName: trimmedName,
            email: contact.email,
            phone: contact.phone
        )
        return try await withCloudActivity(label: "创建监护人") {
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
        try await withCloudActivity(label: "创建学员") {
            _ = try await repository.create(student: student, for: guardianID)
            await reload()
        }
    }

    func link(studentID: StudentID, to guardianID: GuardianID) async throws {
        try await withCloudActivity(label: "关联学员") {
            try await repository.link(studentID: studentID, to: guardianID)
            await reload()
        }
    }

    func issueGuardianLinkCode(guardianID: GuardianID) async throws -> GuardianLinkCode {
        try await withCloudActivity(label: "生成监护人码") {
            let code = try await repository.issueGuardianLinkCode(guardianID: guardianID)
            await reload()
            return code
        }
    }

    func saveGuardian(_ guardian: Guardian) async throws {
        let name = guardian.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppModelError.missingGuardianName }
        let contact = try normalizedGuardianContact(
            email: guardian.email ?? "",
            phone: guardian.phone ?? ""
        )
        var updated = guardian
        updated.displayName = name
        updated.email = contact.email
        updated.phone = contact.phone
        try await withCloudActivity(label: "保存监护人") {
            try await repository.save(guardian: updated)
            await reload()
        }
    }

    private func normalizedGuardianContact(
        email: String,
        phone: String
    ) throws -> (email: String, phone: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { throw AppModelError.missingGuardianEmail }
        guard let normalizedEmail = GuardianContact.normalizedEmail(trimmedEmail) else {
            throw AppModelError.invalidGuardianEmail
        }

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else { throw AppModelError.missingGuardianPhone }
        guard let formattedPhone = GuardianContact.formattedUSPhone(trimmedPhone) else {
            throw AppModelError.invalidGuardianPhone
        }

        return (normalizedEmail, formattedPhone)
    }

    func deleteGuardian(id: GuardianID) async throws {
        try await withCloudActivity(label: "删除监护人") {
            try await repository.deleteGuardian(id: id)
            await reload()
        }
    }

    func saveStudent(_ student: Student) async throws {
        let name = student.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppModelError.missingStudentName }
        var updated = student
        updated.displayName = name
        try await withCloudActivity(label: "保存学员") {
            try await repository.save(student: updated)
            await reload()
        }
    }

    func deleteStudent(id: StudentID) async throws {
        try await withCloudActivity(label: "删除学员") {
            try await repository.deleteStudent(id: id)
            await reload()
        }
    }

    func saveContractDocument(_ document: ContractDocument, fileData: Data?) async throws {
        try await withCloudActivity(label: "保存合同") {
            _ = try await repository.save(contractDocument: document, fileData: fileData)
            await reload()
        }
    }

    func deleteContractDocument(_ document: ContractDocument) async throws {
        try await withCloudActivity(label: "删除合同") {
            try await repository.deleteContractDocument(id: document.id, storagePath: document.storagePath)
            await reload()
        }
    }

    func enroll(studentID: StudentID, courseID: CourseID) async throws {
        guard let course = course(id: courseID) else {
            throw AppModelError.missingEnrollmentFields
        }
        try await withCloudActivity(label: "添加报名") {
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
    }

    func removeEnrollment(id: EnrollmentID) async throws {
        try await withCloudActivity(label: "移除报名") {
            try await repository.deleteEnrollment(id: id)
            await reload()
        }
    }

    func recordAttendance(sessionID: ClassSessionID, studentID: StudentID, status: AttendanceStatus) async throws {
        let matchingEnrollmentID = session(id: sessionID).flatMap { session in
            enrollments.first {
                $0.courseID == session.courseID
                    && $0.studentID == studentID
                    && $0.status == .active
            }?.id
        }
        let enrollmentID = status.isGuestAttendance ? nil : matchingEnrollmentID
        guard status.isGuestAttendance || enrollmentID != nil else {
            throw AppModelError.attendanceRequiresEnrollment
        }
        try await withCloudActivity(label: "记录签到") {
            if let existing = attendance.first(where: { $0.sessionID == sessionID && $0.studentID == studentID }) {
                var updated = existing
                updated.enrollmentID = enrollmentID
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
    }

    func deleteAttendance(id: AttendanceID) async throws {
        try await withCloudActivity(label: "删除签到记录") {
            try await repository.deleteAttendance(id: id)
            await reload()
        }
    }

    func resolveLeaveRequest(id: LeaveRequestID, status: LeaveRequestStatus) async throws {
        guard status == .approved || status == .denied else { return }
        guard var request = leaveRequests.first(where: { $0.id == id }) else { return }
        request.status = status
        request.resolvedAt = Date()
        try await withCloudActivity(label: "处理请假") {
            try await repository.save(leaveRequest: request)
            await reload()
        }
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

    private func refreshBackgroundSyncActivity() {
        backgroundSync.activeCount = pendingBackgroundOperations.count
        backgroundSync.activeLabel = pendingBackgroundOperations.last?.label
    }

    private func withCloudActivity<Value>(
        label: String,
        operation: @MainActor () async throws -> Value
    ) async rethrows -> Value {
        let id = UUID()
        pendingCloudOperations.append(PendingCloudOperation(id: id, label: label))
        refreshCloudActivity()
        defer {
            pendingCloudOperations.removeAll { $0.id == id }
            refreshCloudActivity()
        }
        return try await operation()
    }

    private func refreshCloudActivity() {
        cloudActivity.activeCount = pendingCloudOperations.count
        cloudActivity.activeLabel = pendingCloudOperations.last?.label
    }

    private func completeBackgroundOperation(
        id: UUID,
        successMessage: String,
        error: Error?
    ) {
        pendingBackgroundOperations.removeAll { $0.id == id }
        refreshBackgroundSyncActivity()

        if let error {
            syncNoticeGeneration = UUID()
            backgroundSync.notice = .failure(error.localizedDescription)
            return
        }

        guard pendingBackgroundOperations.isEmpty else { return }
        if case .failure = backgroundSync.notice { return }
        backgroundSync.notice = .success(successMessage)
        scheduleSuccessNoticeDismissal()
    }

    private func scheduleSuccessNoticeDismissal() {
        let generation = UUID()
        syncNoticeGeneration = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard let self,
                  self.syncNoticeGeneration == generation,
                  self.pendingBackgroundOperations.isEmpty,
                  case .success = self.backgroundSync.notice else {
                return
            }
            self.backgroundSync.notice = nil
        }
    }

    private func generatedSessions(
        for courseID: CourseID,
        termID: TermID,
        draft: CourseCreationDraft
    ) throws -> [ClassSession] {
        let holidayDates = termHolidays
            .filter { $0.termID == termID }
            .reduce(into: Set<Date>()) { dates, holiday in
                dates.formUnion(calendarDays(from: holiday.startsOn, through: holiday.endsOn))
            }
        let plan = WeeklySessionPlan(
            courseID: courseID,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            weekday: draft.weekday,
            startTime: draft.startTime,
            endTime: draft.endTime,
            excludedDates: draft.excludedDates.union(holidayDates)
        )
        return try RecurringSessionBuilder.sessions(for: plan, calendar: .masterDance)
    }

    private func sameSchedule(_ lhs: [ClassSession], _ rhs: [ClassSession]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let left = lhs.sorted { $0.startsAt < $1.startsAt }
        let right = rhs.sorted { $0.startsAt < $1.startsAt }
        return zip(left, right).allSatisfy { pair in
            pair.0.startsAt == pair.1.startsAt && pair.0.endsAt == pair.1.endsAt
        }
    }

    private func moving<Value: Identifiable>(
        _ values: [Value],
        sourceID: Value.ID,
        to targetID: Value.ID
    ) -> [Value] {
        guard sourceID != targetID,
              let sourceIndex = values.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = values.firstIndex(where: { $0.id == targetID }) else {
            return values
        }
        var result = values
        let moved = result.remove(at: sourceIndex)
        result.insert(moved, at: min(targetIndex, result.endIndex))
        return result
    }
}

private enum ReferenceOrderKey: String {
    case courseTypes
    case ageGroups
    case rooms
    case instructors

    var defaultsKey: String { "md.referenceOrder.\(rawValue)" }
}

private struct PendingBackgroundOperation {
    let id: UUID
    let label: String
}

private struct PendingCloudOperation {
    let id: UUID
    let label: String
}

private final class ReferenceOrderStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func apply<Value>(
        _ values: [Value],
        key: ReferenceOrderKey,
        id: (Value) -> String
    ) -> [Value] {
        let storedOrder = defaults.stringArray(forKey: key.defaultsKey) ?? []
        guard !storedOrder.isEmpty else { return values }
        let positions = Dictionary(uniqueKeysWithValues: storedOrder.enumerated().map { ($0.element, $0.offset) })
        return values.enumerated().sorted { lhs, rhs in
            let left = positions[id(lhs.element)]
            let right = positions[id(rhs.element)]
            switch (left, right) {
            case let (.some(left), .some(right)): return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    func save<Value>(
        _ values: [Value],
        key: ReferenceOrderKey,
        id: (Value) -> String
    ) {
        defaults.set(values.map(id), forKey: key.defaultsKey)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
