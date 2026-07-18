import Foundation

public struct PreviewData: Sendable {
    public var terms: [Term]
    public var termHolidays: [TermHoliday]
    public var courseCategories: [CourseCategory]
    public var courseTypes: [CourseType]
    public var ageGroups: [AgeGroup]
    public var rooms: [Room]
    public var instructors: [Instructor]
    public var courses: [Course]
    public var sessions: [ClassSession]
    public var students: [Student]
    public var guardians: [Guardian]
    public var enrollments: [Enrollment]
    public var attendance: [Attendance]
    public var leaveRequests: [LeaveRequest]
    public var contractDocuments: [ContractDocument]
    public var contractConsents: [ContractConsent]
    public var notifications: [NotificationRecord]

    public init(
        terms: [Term] = [],
        termHolidays: [TermHoliday] = [],
        courseCategories: [CourseCategory] = [],
        courseTypes: [CourseType] = [],
        ageGroups: [AgeGroup] = [],
        rooms: [Room] = [],
        instructors: [Instructor] = [],
        courses: [Course] = [],
        sessions: [ClassSession] = [],
        students: [Student] = [],
        guardians: [Guardian] = [],
        enrollments: [Enrollment] = [],
        attendance: [Attendance] = [],
        leaveRequests: [LeaveRequest] = [],
        contractDocuments: [ContractDocument] = [],
        contractConsents: [ContractConsent] = [],
        notifications: [NotificationRecord] = []
    ) {
        self.terms = terms
        self.termHolidays = termHolidays
        self.courseCategories = courseCategories
        self.courseTypes = courseTypes
        self.ageGroups = ageGroups
        self.rooms = rooms
        self.instructors = instructors
        self.courses = courses
        self.sessions = sessions
        self.students = students
        self.guardians = guardians
        self.enrollments = enrollments
        self.attendance = attendance
        self.leaveRequests = leaveRequests
        self.contractDocuments = contractDocuments
        self.contractConsents = contractConsents
        self.notifications = notifications
    }
}

public actor PreviewMasterDanceStore: MasterDanceRepository {
    private var data: PreviewData

    public init(data: PreviewData = PreviewData()) {
        self.data = data
    }

    public func listTerms() -> [Term] { data.terms }
    public func save(term: Term) throws {
        guard term.startsOn <= term.endsOn else {
            throw PreviewRepositoryError.invalidTermRange
        }
        guard data.termHolidays.filter({ $0.termID == term.id }).allSatisfy({
            $0.startsOn >= term.startsOn && $0.endsOn <= term.endsOn
        }) else {
            throw PreviewRepositoryError.holidayOutsideTerm
        }
        upsert(term, in: &data.terms)
    }
    public func deleteTerm(id: TermID) throws {
        guard !data.courses.contains(where: { $0.termID == id })
                && !data.termHolidays.contains(where: { $0.termID == id })
                && !data.contractDocuments.contains(where: { $0.termID == id }) else {
            throw PreviewRepositoryError.recordInUse("这个学期已有课程、假期或合同，不能删除。")
        }
        remove(id: id, from: &data.terms)
    }

    public func listTermHolidays(termID: TermID? = nil) -> [TermHoliday] {
        data.termHolidays.filter { termID == nil || $0.termID == termID }
    }

    public func save(termHoliday: TermHoliday) throws {
        guard let term = data.terms.first(where: { $0.id == termHoliday.termID }) else {
            throw PreviewRepositoryError.termNotFound
        }
        guard termHoliday.startsOn <= termHoliday.endsOn else {
            throw PreviewRepositoryError.invalidTermRange
        }
        guard termHoliday.startsOn >= term.startsOn, termHoliday.endsOn <= term.endsOn else {
            throw PreviewRepositoryError.holidayOutsideTerm
        }
        upsert(termHoliday, in: &data.termHolidays)
    }
    public func deleteTermHoliday(id: TermHolidayID) { remove(id: id, from: &data.termHolidays) }

    public func listCourseCategories() -> [CourseCategory] { data.courseCategories }
    public func listCourseTypes() -> [CourseType] { data.courseTypes }
    public func listAgeGroups() -> [AgeGroup] { data.ageGroups }
    public func listRooms() -> [Room] { data.rooms }
    public func listInstructors() -> [Instructor] { data.instructors }
    public func save(courseCategory: CourseCategory) { upsert(courseCategory, in: &data.courseCategories) }
    public func save(courseType: CourseType) {
        upsert(courseType, in: &data.courseTypes)
        for index in data.courses.indices where data.courses[index].courseTypeID == courseType.id {
            data.courses[index].format = courseType.isPrivate ? .privateLesson : .group
        }
    }
    public func save(ageGroup: AgeGroup) { upsert(ageGroup, in: &data.ageGroups) }
    public func save(room: Room) { upsert(room, in: &data.rooms) }
    public func save(instructor: Instructor) { upsert(instructor, in: &data.instructors) }
    public func deleteCourseCategory(id: CourseCategoryID) throws {
        try requireUnused(!data.courses.contains { $0.categoryID == id }, "这个课程分类已被课程使用，不能删除。")
        remove(id: id, from: &data.courseCategories)
    }
    public func deleteCourseType(id: CourseTypeID) throws {
        try requireUnused(!data.courses.contains { $0.courseTypeID == id }, "这个课程种类已被课程使用，不能删除。")
        remove(id: id, from: &data.courseTypes)
    }
    public func deleteAgeGroup(id: AgeGroupID) throws {
        try requireUnused(!data.courses.contains { $0.ageGroupID == id }, "这个年龄段已被课程使用，不能删除。")
        remove(id: id, from: &data.ageGroups)
    }
    public func deleteRoom(id: RoomID) throws {
        let inUse = data.courses.contains { $0.defaultRoomID == id }
            || data.sessions.contains { $0.roomOverrideID == id }
        try requireUnused(!inUse, "这个教室已被课程或课次使用，不能删除。")
        remove(id: id, from: &data.rooms)
    }
    public func deleteInstructor(id: InstructorID) throws {
        let inUse = data.courses.contains { $0.defaultInstructorID == id }
            || data.sessions.contains { $0.instructorOverrideID == id }
        try requireUnused(!inUse, "这位老师已被课程或课次使用，不能删除。")
        remove(id: id, from: &data.instructors)
    }

    public func listCourses(termID: TermID? = nil) -> [Course] {
        data.courses.filter { termID == nil || $0.termID == termID }
    }

    public func save(course: Course) { upsert(course, in: &data.courses) }
    public func deleteCourse(id: CourseID) throws {
        let inUse = data.sessions.contains { $0.courseID == id }
            || data.enrollments.contains { $0.courseID == id }
        try requireUnused(!inUse, "这门课程已有课次或报名，不能删除；可以将它停用。")
        remove(id: id, from: &data.courses)
    }

    public func listSessions(courseID: CourseID? = nil) -> [ClassSession] {
        data.sessions.filter { courseID == nil || $0.courseID == courseID }
    }

    public func save(session: ClassSession) { upsert(session, in: &data.sessions) }
    public func deleteSession(id: ClassSessionID) throws {
        let inUse = data.attendance.contains { $0.sessionID == id }
            || data.leaveRequests.contains { $0.sessionID == id }
        try requireUnused(!inUse, "这次课已有签到或请假记录，不能删除。")
        remove(id: id, from: &data.sessions)
    }

    public func listStudents() -> [Student] { data.students }

    public func listGuardians(studentID: StudentID? = nil) -> [Guardian] {
        let guardians = data.guardians.map { guardian in
            var guardian = guardian
            guardian.studentIDs = Set(
                data.students.filter { $0.guardianID == guardian.id }.map(\.id)
            )
            return guardian
        }
        guard let studentID,
              let guardianID = data.students.first(where: { $0.id == studentID })?.guardianID else {
            return studentID == nil ? guardians : []
        }
        return guardians.filter { $0.id == guardianID }
    }

    public func save(student: Student) throws {
        guard data.guardians.contains(where: { $0.id == student.guardianID }) else {
            throw PreviewRepositoryError.guardianNotFound
        }
        upsert(student, in: &data.students)
    }
    public func save(guardian: Guardian) { upsert(guardian, in: &data.guardians) }

    public func create(student: Student, for guardianID: GuardianID) throws -> Student {
        guard let guardianIndex = data.guardians.firstIndex(where: { $0.id == guardianID }) else {
            throw PreviewRepositoryError.guardianNotFound
        }

        var created = student
        created.guardianID = guardianID
        upsert(created, in: &data.students)
        data.guardians[guardianIndex].studentIDs.insert(created.id)
        return created
    }

    public func link(studentID: StudentID, to guardianID: GuardianID) throws {
        guard let studentIndex = data.students.firstIndex(where: { $0.id == studentID }) else {
            throw PreviewRepositoryError.studentNotFound
        }
        guard let guardianIndex = data.guardians.firstIndex(where: { $0.id == guardianID }) else {
            throw PreviewRepositoryError.guardianNotFound
        }
        data.students[studentIndex].guardianID = guardianID
        for index in data.guardians.indices {
            data.guardians[index].studentIDs.remove(studentID)
        }
        data.guardians[guardianIndex].studentIDs.insert(studentID)
    }

    public func issueGuardianLinkCode(guardianID: GuardianID) throws -> GuardianLinkCode {
        guard let guardianIndex = data.guardians.firstIndex(where: { $0.id == guardianID }) else {
            throw PreviewRepositoryError.guardianNotFound
        }
        guard !data.guardians[guardianIndex].isAccountLinked else {
            throw PreviewRepositoryError.guardianAlreadyLinked
        }

        let randomPart = String(
            UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .prefix(20)
        )
        let groups = stride(from: 0, to: randomPart.count, by: 4).map { offset in
            let start = randomPart.index(randomPart.startIndex, offsetBy: offset)
            let remaining = randomPart.distance(from: start, to: randomPart.endIndex)
            let end = randomPart.index(start, offsetBy: min(4, remaining))
            return String(randomPart[start..<end])
        }
        let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        data.guardians[guardianIndex].activeLinkCodeHint = String(randomPart.suffix(4))
        data.guardians[guardianIndex].activeLinkCodeExpiresAt = expiresAt
        return GuardianLinkCode(
            guardianID: guardianID,
            code: "MD-" + groups.joined(separator: "-"),
            expiresAt: expiresAt
        )
    }

    public func deleteStudent(id: StudentID) throws {
        let inUse = data.enrollments.contains { $0.studentID == id }
            || data.attendance.contains { $0.studentID == id }
            || data.leaveRequests.contains { $0.studentID == id }
        try requireUnused(!inUse, "这个学员已有报名、签到或请假记录，不能删除；可以将档案停用。")
        remove(id: id, from: &data.students)
    }

    public func deleteGuardian(id: GuardianID) throws {
        guard let guardian = data.guardians.first(where: { $0.id == id }) else { return }
        let inUse = guardian.isAccountLinked || data.students.contains { $0.guardianID == id }
        try requireUnused(!inUse, "这个监护人已连接帐号或仍有学员档案，不能删除。")
        remove(id: id, from: &data.guardians)
    }

    public func listEnrollments(
        termID: TermID? = nil,
        courseID: CourseID? = nil,
        studentID: StudentID? = nil
    ) -> [Enrollment] {
        data.enrollments.filter {
            (termID == nil || $0.termID == termID)
                && (courseID == nil || $0.courseID == courseID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(enrollment: Enrollment) { upsert(enrollment, in: &data.enrollments) }
    public func deleteEnrollment(id: EnrollmentID) { remove(id: id, from: &data.enrollments) }

    public func listAttendance(
        sessionID: ClassSessionID? = nil,
        studentID: StudentID? = nil
    ) -> [Attendance] {
        data.attendance.filter {
            (sessionID == nil || $0.sessionID == sessionID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(attendance: Attendance) { upsert(attendance, in: &data.attendance) }
    public func deleteAttendance(id: AttendanceID) { remove(id: id, from: &data.attendance) }

    public func listLeaveRequests(
        sessionID: ClassSessionID? = nil,
        studentID: StudentID? = nil
    ) -> [LeaveRequest] {
        data.leaveRequests.filter {
            (sessionID == nil || $0.sessionID == sessionID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(leaveRequest: LeaveRequest) { upsert(leaveRequest, in: &data.leaveRequests) }

    public func listContractDocuments(termID: TermID? = nil) -> [ContractDocument] {
        data.contractDocuments.filter { termID == nil || $0.termID == termID }
    }

    public func save(
        contractDocument: ContractDocument,
        fileData: Data?
    ) -> ContractDocument {
        var saved = contractDocument
        if saved.storagePath.isEmpty, fileData != nil {
            saved.storagePath = "preview/\(saved.id.rawValue.uuidString.lowercased()).pdf"
        }
        upsert(saved, in: &data.contractDocuments)
        return saved
    }

    public func deleteContractDocument(
        id: ContractDocumentID,
        storagePath: String
    ) throws {
        let inUse = data.contractConsents.contains { $0.contractDocumentID == id }
        try requireUnused(!inUse, "这份合同已有签署记录，不能删除；可以将它停用。")
        remove(id: id, from: &data.contractDocuments)
    }

    public func listContractConsents(
        termID: TermID,
        enrollmentID: EnrollmentID? = nil
    ) -> [ContractConsent] {
        data.contractConsents.filter {
            $0.termID == termID && (enrollmentID == nil || $0.enrollmentID == enrollmentID)
        }
    }

    public func save(contractConsent: ContractConsent) {
        upsert(contractConsent, in: &data.contractConsents)
    }

    public func listNotifications(recipientReference: String? = nil) -> [NotificationRecord] {
        data.notifications.filter {
            recipientReference == nil || $0.recipientReference == recipientReference
        }
    }

    public func save(notification: NotificationRecord) {
        upsert(notification, in: &data.notifications)
    }

    public static func sample(now: Date = Date()) -> PreviewMasterDanceStore {
        PreviewMasterDanceStore(data: .masterDanceSample(now: now))
    }

    private func upsert<Value: Identifiable>(_ value: Value, in values: inout [Value]) where Value.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
    }

    private func remove<Value: Identifiable>(id: Value.ID, from values: inout [Value]) where Value.ID: Equatable {
        values.removeAll { $0.id == id }
    }

    private func requireUnused(_ condition: Bool, _ message: String) throws {
        guard condition else { throw PreviewRepositoryError.recordInUse(message) }
    }
}

public enum PreviewRepositoryError: LocalizedError, Sendable, Equatable {
    case guardianNotFound
    case studentNotFound
    case guardianAlreadyLinked
    case recordInUse(String)
    case termNotFound
    case invalidTermRange
    case holidayOutsideTerm

    public var errorDescription: String? {
        switch self {
        case .guardianNotFound:
            "找不到这个监护人。"
        case .studentNotFound:
            "找不到这个学员档案。"
        case .guardianAlreadyLinked:
            "这个监护人已经连接帐号。"
        case let .recordInUse(message):
            message
        case .termNotFound:
            "找不到这个学期。"
        case .invalidTermRange:
            "结束日期不能早于开始日期。"
        case .holidayOutsideTerm:
            "假期日期必须位于学期范围内。"
        }
    }
}
