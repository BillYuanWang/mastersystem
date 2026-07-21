import Foundation

public protocol DeferredSyncMasterDanceRepository: MasterDanceRepository {
    func pendingMutationCount() async -> Int
    @discardableResult func synchronizeIfNeeded() async throws -> Int
    @discardableResult func refreshFromRemoteIfClean() async throws -> Bool
    @discardableResult func refreshFromRemoteIfChanged() async throws -> Bool
}

public actor WriteBehindMasterDanceRepository: DeferredSyncMasterDanceRepository {
    private let remote: any MasterDanceRepository
    private let local: PreviewMasterDanceStore
    private let cacheURL: URL
    private let latestRemoteChangeSequence: (@Sendable () async throws -> Int64?)?
    private var pendingMutations: [QueuedMutation]
    private var hasSnapshot: Bool
    private var hasLoadedCache = false
    private var isSynchronizing = false
    private var lastRemoteRefreshAt: Date?
    private var lastRemoteChangeSequence: Int64?

    public init(
        remote: any MasterDanceRepository,
        cacheDirectory: URL,
        cacheKey: String,
        latestRemoteChangeSequence: (@Sendable () async throws -> Int64?)? = nil
    ) {
        self.remote = remote
        self.latestRemoteChangeSequence = latestRemoteChangeSequence
        let safeCacheKey = cacheKey.map {
            $0.isLetter || $0.isNumber ? String($0) : "-"
        }.joined()
        cacheURL = cacheDirectory
            .appendingPathComponent("master-dance-\(safeCacheKey).json", isDirectory: false)

        local = PreviewMasterDanceStore()
        pendingMutations = []
        hasSnapshot = false
    }

    public func pendingMutationCount() async -> Int {
        await loadCacheIfNeeded()
        return pendingMutations.count
    }

    @discardableResult
    public func synchronizeIfNeeded() async throws -> Int {
        await loadCacheIfNeeded()
        guard !isSynchronizing, !pendingMutations.isEmpty else { return 0 }
        isSynchronizing = true
        defer { isSynchronizing = false }

        var synchronizedCount = 0
        while let queued = pendingMutations.first {
            try await queued.mutation.apply(to: remote)
            pendingMutations.removeAll { $0.id == queued.id }
            synchronizedCount += 1
            try await persist()
        }
        return synchronizedCount
    }

    @discardableResult
    public func refreshFromRemoteIfClean() async throws -> Bool {
        await loadCacheIfNeeded()
        guard pendingMutations.isEmpty, !isSynchronizing else { return false }
        if let lastRemoteRefreshAt,
           Date().timeIntervalSince(lastRemoteRefreshAt) < 5 {
            return false
        }

        let changeSequence = try await currentRemoteChangeSequence()
        let snapshot = try await fetchRemoteSnapshot()
        guard pendingMutations.isEmpty, !isSynchronizing else { return false }
        await local.replace(with: snapshot)
        hasSnapshot = true
        lastRemoteRefreshAt = Date()
        lastRemoteChangeSequence = changeSequence
        try await persist()
        return true
    }

    @discardableResult
    public func refreshFromRemoteIfChanged() async throws -> Bool {
        await loadCacheIfNeeded()
        guard pendingMutations.isEmpty, !isSynchronizing else { return false }
        guard latestRemoteChangeSequence != nil else {
            return try await refreshFromRemoteIfClean()
        }

        let changeSequence = try await currentRemoteChangeSequence()
        guard changeSequence != lastRemoteChangeSequence else { return false }

        let snapshot = try await fetchRemoteSnapshot()
        guard pendingMutations.isEmpty, !isSynchronizing else { return false }
        await local.replace(with: snapshot)
        hasSnapshot = true
        lastRemoteRefreshAt = Date()
        lastRemoteChangeSequence = changeSequence
        try await persist()
        return true
    }

    public func listTerms() async throws -> [Term] {
        try await ensureSnapshot()
        return await local.listTerms()
    }

    public func save(term: Term) async throws {
        try await ensureSnapshot()
        try await local.save(term: term)
        try await enqueue(.saveTerm(term))
    }

    public func deleteTerm(id: TermID) async throws {
        try await ensureSnapshot()
        try await local.deleteTerm(id: id)
        try await enqueue(.deleteTerm(id))
    }

    public func listTermHolidays(termID: TermID?) async throws -> [TermHoliday] {
        try await ensureSnapshot()
        return await local.listTermHolidays(termID: termID)
    }

    public func save(termHoliday: TermHoliday) async throws {
        try await ensureSnapshot()
        try await local.save(termHoliday: termHoliday)
        try await enqueue(.saveTermHoliday(termHoliday))
    }

    public func deleteTermHoliday(id: TermHolidayID) async throws {
        try await ensureSnapshot()
        try await local.deleteTermHoliday(id: id)
        try await enqueue(.deleteTermHoliday(id))
    }

    public func listCourseCategories() async throws -> [CourseCategory] {
        try await ensureSnapshot()
        return await local.listCourseCategories()
    }

    public func listCourseTypes() async throws -> [CourseType] {
        try await ensureSnapshot()
        return await local.listCourseTypes()
    }

    public func listAgeGroups() async throws -> [AgeGroup] {
        try await ensureSnapshot()
        return await local.listAgeGroups()
    }

    public func listRooms() async throws -> [Room] {
        try await ensureSnapshot()
        return await local.listRooms()
    }

    public func listInstructors() async throws -> [Instructor] {
        try await ensureSnapshot()
        return await local.listInstructors()
    }

    public func save(courseCategory: CourseCategory) async throws {
        try await ensureSnapshot()
        await local.save(courseCategory: courseCategory)
        try await enqueue(.saveCourseCategory(courseCategory))
    }

    public func save(courseType: CourseType) async throws {
        try await ensureSnapshot()
        await local.save(courseType: courseType)
        try await enqueue(.saveCourseType(courseType))
    }

    public func save(ageGroup: AgeGroup) async throws {
        try await ensureSnapshot()
        await local.save(ageGroup: ageGroup)
        try await enqueue(.saveAgeGroup(ageGroup))
    }

    public func save(room: Room) async throws {
        try await ensureSnapshot()
        await local.save(room: room)
        try await enqueue(.saveRoom(room))
    }

    public func save(instructor: Instructor) async throws {
        try await ensureSnapshot()
        await local.save(instructor: instructor)
        try await enqueue(.saveInstructor(instructor))
    }

    public func deleteCourseCategory(id: CourseCategoryID) async throws {
        try await ensureSnapshot()
        try await local.deleteCourseCategory(id: id)
        try await enqueue(.deleteCourseCategory(id))
    }

    public func deleteCourseType(id: CourseTypeID) async throws {
        try await ensureSnapshot()
        try await local.deleteCourseType(id: id)
        try await enqueue(.deleteCourseType(id))
    }

    public func deleteAgeGroup(id: AgeGroupID) async throws {
        try await ensureSnapshot()
        try await local.deleteAgeGroup(id: id)
        try await enqueue(.deleteAgeGroup(id))
    }

    public func deleteRoom(id: RoomID) async throws {
        try await ensureSnapshot()
        try await local.deleteRoom(id: id)
        try await enqueue(.deleteRoom(id))
    }

    public func deleteInstructor(id: InstructorID) async throws {
        try await ensureSnapshot()
        try await local.deleteInstructor(id: id)
        try await enqueue(.deleteInstructor(id))
    }

    public func listCourses(termID: TermID?) async throws -> [Course] {
        try await ensureSnapshot()
        return await local.listCourses(termID: termID)
    }

    public func save(course: Course) async throws {
        try await ensureSnapshot()
        try await local.save(course: course)
        try await enqueue(.saveCourse(course))
    }

    public func deleteCourse(id: CourseID) async throws {
        try await ensureSnapshot()
        try await local.deleteCourse(id: id)
        try await enqueue(.deleteCourse(id))
    }

    public func listSessions(courseID: CourseID?) async throws -> [ClassSession] {
        try await ensureSnapshot()
        return await local.listSessions(courseID: courseID)
    }

    public func save(session: ClassSession) async throws {
        try await ensureSnapshot()
        await local.save(session: session)
        try await enqueue(.saveSession(session))
    }

    public func deleteSession(id: ClassSessionID) async throws {
        try await ensureSnapshot()
        try await local.deleteSession(id: id)
        try await enqueue(.deleteSession(id))
    }

    public func listStudents() async throws -> [Student] {
        try await ensureSnapshot()
        return await local.listStudents()
    }

    public func listGuardians(studentID: StudentID?) async throws -> [Guardian] {
        try await ensureSnapshot()
        return await local.listGuardians(studentID: studentID)
    }

    public func save(student: Student) async throws {
        try await ensureSnapshot()
        try await local.save(student: student)
        try await enqueue(.saveStudent(student))
    }

    public func save(guardian: Guardian) async throws {
        try await ensureSnapshot()
        await local.save(guardian: guardian)
        try await enqueue(.saveGuardian(guardian))
    }

    public func create(student: Student, for guardianID: GuardianID) async throws -> Student {
        try await ensureSnapshot()
        let created = try await local.create(student: student, for: guardianID)
        try await enqueue(.createStudent(created, guardianID))
        return created
    }

    public func link(studentID: StudentID, to guardianID: GuardianID) async throws {
        try await ensureSnapshot()
        try await local.link(studentID: studentID, to: guardianID)
        try await enqueue(.linkStudent(studentID, guardianID))
    }

    public func issueGuardianLinkCode(guardianID: GuardianID) async throws -> GuardianLinkCode {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        let code = try await remote.issueGuardianLinkCode(guardianID: guardianID)
        var snapshot = await local.snapshot()
        snapshot.guardians = try await remote.listGuardians(studentID: nil)
        await local.replace(with: snapshot)
        try await persist()
        return code
    }

    public func deleteStudent(id: StudentID) async throws {
        try await ensureSnapshot()
        try await local.deleteStudent(id: id)
        try await enqueue(.deleteStudent(id))
    }

    public func deleteGuardian(id: GuardianID) async throws {
        try await ensureSnapshot()
        try await local.deleteGuardian(id: id)
        try await enqueue(.deleteGuardian(id))
    }

    public func listEnrollments(
        termID: TermID?,
        courseID: CourseID?,
        studentID: StudentID?
    ) async throws -> [Enrollment] {
        try await ensureSnapshot()
        return await local.listEnrollments(
            termID: termID,
            courseID: courseID,
            studentID: studentID
        )
    }

    public func save(enrollment: Enrollment) async throws {
        try await ensureSnapshot()
        await local.save(enrollment: enrollment)
        try await enqueue(.saveEnrollment(enrollment))
    }

    public func deleteEnrollment(id: EnrollmentID) async throws {
        try await ensureSnapshot()
        await local.deleteEnrollment(id: id)
        try await enqueue(.deleteEnrollment(id))
    }

    public func listAttendance(
        sessionID: ClassSessionID?,
        studentID: StudentID?
    ) async throws -> [Attendance] {
        try await ensureSnapshot()
        return await local.listAttendance(sessionID: sessionID, studentID: studentID)
    }

    public func save(attendance: Attendance) async throws {
        try await ensureSnapshot()
        await local.save(attendance: attendance)
        try await enqueue(.saveAttendance(attendance))
    }

    public func deleteAttendance(id: AttendanceID) async throws {
        try await ensureSnapshot()
        await local.deleteAttendance(id: id)
        try await enqueue(.deleteAttendance(id))
    }

    public func listLeaveRequests(
        sessionID: ClassSessionID?,
        studentID: StudentID?
    ) async throws -> [LeaveRequest] {
        try await ensureSnapshot()
        return await local.listLeaveRequests(sessionID: sessionID, studentID: studentID)
    }

    public func save(leaveRequest: LeaveRequest) async throws {
        try await ensureSnapshot()
        await local.save(leaveRequest: leaveRequest)
        try await enqueue(.saveLeaveRequest(leaveRequest))
    }

    public func deleteLeaveRequest(id: LeaveRequestID) async throws {
        try await ensureSnapshot()
        await local.deleteLeaveRequest(id: id)
        try await enqueue(.deleteLeaveRequest(id))
    }

    public func listContractDocuments(termID: TermID?) async throws -> [ContractDocument] {
        try await ensureSnapshot()
        return await local.listContractDocuments(termID: termID)
    }

    public func save(
        contractDocument: ContractDocument,
        fileData: Data?
    ) async throws -> ContractDocument {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        let saved = try await remote.save(contractDocument: contractDocument, fileData: fileData)
        _ = await local.save(contractDocument: saved, fileData: nil)
        try await persist()
        return saved
    }

    public func publishContractRevision(
        termID: TermID,
        title: String,
        bodyText: String
    ) async throws -> ContractDocument {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        let saved = try await remote.publishContractRevision(
            termID: termID,
            title: title,
            bodyText: bodyText
        )
        let snapshot = try await fetchRemoteSnapshot()
        await local.replace(with: snapshot)
        hasSnapshot = true
        lastRemoteRefreshAt = Date()
        try await persist()
        return saved
    }

    public func deleteContractDocument(
        id: ContractDocumentID,
        storagePath: String
    ) async throws {
        try await ensureSnapshot()
        try await local.deleteContractDocument(id: id, storagePath: storagePath)
        try await enqueue(.deleteContractDocument(id, storagePath))
    }

    public func listContractConsents(
        termID: TermID,
        enrollmentID: EnrollmentID?
    ) async throws -> [ContractConsent] {
        try await ensureSnapshot()
        return await local.listContractConsents(termID: termID, enrollmentID: enrollmentID)
    }

    public func save(contractConsent: ContractConsent) async throws {
        try await ensureSnapshot()
        await local.save(contractConsent: contractConsent)
        try await enqueue(.saveContractConsent(contractConsent))
    }

    public func listNewsArticles() async throws -> [NewsArticle] {
        try await ensureSnapshot()
        return await local.listNewsArticles()
    }

    public func listNewsArticleImages(articleID: NewsArticleID?) async throws -> [NewsArticleImage] {
        try await ensureSnapshot()
        return await local.listNewsArticleImages(articleID: articleID)
    }

    public func save(newsArticle: NewsArticle) async throws -> NewsArticle {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        let saved = try await remote.save(newsArticle: newsArticle)
        _ = await local.save(newsArticle: saved)
        try await persist()
        return saved
    }

    public func save(
        newsArticleImage: NewsArticleImage,
        fileData: Data?
    ) async throws -> NewsArticleImage {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        let saved = try await remote.save(newsArticleImage: newsArticleImage, fileData: fileData)
        _ = try await local.save(newsArticleImage: saved, fileData: fileData)
        try await persist()
        return saved
    }

    public func deleteNewsArticle(id: NewsArticleID) async throws {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        try await remote.deleteNewsArticle(id: id)
        await local.deleteNewsArticle(id: id)
        try await persist()
    }

    public func deleteNewsArticleImage(
        id: NewsArticleImageID,
        storagePath: String
    ) async throws {
        try await ensureSnapshot()
        _ = try await synchronizeIfNeeded()
        try await remote.deleteNewsArticleImage(id: id, storagePath: storagePath)
        await local.deleteNewsArticleImage(id: id, storagePath: storagePath)
        try await persist()
    }

    public func newsMediaData(storagePath: String) async throws -> Data {
        try await remote.newsMediaData(storagePath: storagePath)
    }

    public func listNotifications(recipientReference: String?) async throws -> [NotificationRecord] {
        try await ensureSnapshot()
        return await local.listNotifications(recipientReference: recipientReference)
    }

    public func save(notification: NotificationRecord) async throws {
        try await ensureSnapshot()
        await local.save(notification: notification)
        try await enqueue(.saveNotification(notification))
    }

    private func ensureSnapshot() async throws {
        await loadCacheIfNeeded()
        guard !hasSnapshot else { return }
        let changeSequence = try await currentRemoteChangeSequence()
        let snapshot = try await fetchRemoteSnapshot()
        await local.replace(with: snapshot)
        hasSnapshot = true
        lastRemoteRefreshAt = Date()
        lastRemoteChangeSequence = changeSequence
        try await persist()
    }

    private func loadCacheIfNeeded() async {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true

        guard let data = try? Data(contentsOf: cacheURL),
              let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
              envelope.version == CacheEnvelope.currentVersion else {
            return
        }

        await local.replace(with: envelope.snapshot)
        pendingMutations = envelope.pendingMutations
        lastRemoteChangeSequence = envelope.lastRemoteChangeSequence
        hasSnapshot = true
    }

    private func currentRemoteChangeSequence() async throws -> Int64? {
        guard let latestRemoteChangeSequence else { return nil }
        return try await latestRemoteChangeSequence()
    }

    private func fetchRemoteSnapshot() async throws -> PreviewData {
        let terms = try await remote.listTerms()
        let termHolidays = try await remote.listTermHolidays(termID: nil)
        let courseCategories = try await remote.listCourseCategories()
        let courseTypes = try await remote.listCourseTypes()
        let ageGroups = try await remote.listAgeGroups()
        let rooms = try await remote.listRooms()
        let instructors = try await remote.listInstructors()
        let courses = try await remote.listCourses(termID: nil)
        let sessions = try await remote.listSessions(courseID: nil)
        let students = try await remote.listStudents()
        let guardians = try await remote.listGuardians(studentID: nil)
        let enrollments = try await remote.listEnrollments(
            termID: nil,
            courseID: nil,
            studentID: nil
        )
        let attendance = try await remote.listAttendance(sessionID: nil, studentID: nil)
        let leaveRequests = try await remote.listLeaveRequests(sessionID: nil, studentID: nil)
        let contractDocuments = try await remote.listContractDocuments(termID: nil)
        var contractConsents: [ContractConsent] = []
        for term in terms {
            contractConsents += try await remote.listContractConsents(
                termID: term.id,
                enrollmentID: nil
            )
        }
        let newsArticles = try await remote.listNewsArticles()
        let newsArticleImages = try await remote.listNewsArticleImages(articleID: nil)
        let notifications = try await remote.listNotifications(recipientReference: nil)

        return PreviewData(
            terms: terms,
            termHolidays: termHolidays,
            courseCategories: courseCategories,
            courseTypes: courseTypes,
            ageGroups: ageGroups,
            rooms: rooms,
            instructors: instructors,
            courses: courses,
            sessions: sessions,
            students: students,
            guardians: guardians,
            enrollments: enrollments,
            attendance: attendance,
            leaveRequests: leaveRequests,
            contractDocuments: contractDocuments,
            contractConsents: contractConsents,
            newsArticles: newsArticles,
            newsArticleImages: newsArticleImages,
            notifications: notifications
        )
    }

    private func enqueue(_ mutation: PendingMutation) async throws {
        let queued = QueuedMutation(mutation: mutation)
        let firstReplaceableIndex = isSynchronizing ? 1 : 0
        if firstReplaceableIndex < pendingMutations.count,
           let index = pendingMutations[firstReplaceableIndex...]
            .firstIndex(where: { $0.mutation.coalescingKey == mutation.coalescingKey }) {
            pendingMutations[index] = queued
        } else {
            pendingMutations.append(queued)
        }
        try await persist()
    }

    private func persist() async throws {
        let snapshot = await local.snapshot()
        let envelope = CacheEnvelope(
            snapshot: snapshot,
            pendingMutations: pendingMutations,
            lastRemoteChangeSequence: lastRemoteChangeSequence
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: cacheURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: cacheURL.path
        )
    }
}

private struct CacheEnvelope: Codable {
    static let currentVersion = 2

    let version: Int
    let snapshot: PreviewData
    let pendingMutations: [QueuedMutation]
    let lastRemoteChangeSequence: Int64?

    init(
        snapshot: PreviewData,
        pendingMutations: [QueuedMutation],
        lastRemoteChangeSequence: Int64?
    ) {
        version = Self.currentVersion
        self.snapshot = snapshot
        self.pendingMutations = pendingMutations
        self.lastRemoteChangeSequence = lastRemoteChangeSequence
    }
}

private struct QueuedMutation: Codable, Sendable {
    let id: UUID
    let mutation: PendingMutation

    init(id: UUID = UUID(), mutation: PendingMutation) {
        self.id = id
        self.mutation = mutation
    }
}

private enum PendingMutation: Codable, Sendable {
    case saveTerm(Term)
    case deleteTerm(TermID)
    case saveTermHoliday(TermHoliday)
    case deleteTermHoliday(TermHolidayID)
    case saveCourseCategory(CourseCategory)
    case deleteCourseCategory(CourseCategoryID)
    case saveCourseType(CourseType)
    case deleteCourseType(CourseTypeID)
    case saveAgeGroup(AgeGroup)
    case deleteAgeGroup(AgeGroupID)
    case saveRoom(Room)
    case deleteRoom(RoomID)
    case saveInstructor(Instructor)
    case deleteInstructor(InstructorID)
    case saveCourse(Course)
    case deleteCourse(CourseID)
    case saveSession(ClassSession)
    case deleteSession(ClassSessionID)
    case saveStudent(Student)
    case createStudent(Student, GuardianID)
    case linkStudent(StudentID, GuardianID)
    case deleteStudent(StudentID)
    case saveGuardian(Guardian)
    case deleteGuardian(GuardianID)
    case saveEnrollment(Enrollment)
    case deleteEnrollment(EnrollmentID)
    case saveAttendance(Attendance)
    case deleteAttendance(AttendanceID)
    case saveLeaveRequest(LeaveRequest)
    case deleteLeaveRequest(LeaveRequestID)
    case deleteContractDocument(ContractDocumentID, String)
    case saveContractConsent(ContractConsent)
    case saveNotification(NotificationRecord)

    var coalescingKey: String {
        switch self {
        case .saveTerm(let value): "term:\(value.id)"
        case .deleteTerm(let id): "term:\(id)"
        case .saveTermHoliday(let value): "term-holiday:\(value.id)"
        case .deleteTermHoliday(let id): "term-holiday:\(id)"
        case .saveCourseCategory(let value): "course-category:\(value.id)"
        case .deleteCourseCategory(let id): "course-category:\(id)"
        case .saveCourseType(let value): "course-type:\(value.id)"
        case .deleteCourseType(let id): "course-type:\(id)"
        case .saveAgeGroup(let value): "age-group:\(value.id)"
        case .deleteAgeGroup(let id): "age-group:\(id)"
        case .saveRoom(let value): "room:\(value.id)"
        case .deleteRoom(let id): "room:\(id)"
        case .saveInstructor(let value): "instructor:\(value.id)"
        case .deleteInstructor(let id): "instructor:\(id)"
        case .saveCourse(let value): "course:\(value.id)"
        case .deleteCourse(let id): "course:\(id)"
        case .saveSession(let value): "session:\(value.id)"
        case .deleteSession(let id): "session:\(id)"
        case .saveStudent(let value): "student:\(value.id)"
        case .createStudent(let value, _): "student-create:\(value.id)"
        case .linkStudent(let id, _): "student-link:\(id)"
        case .deleteStudent(let id): "student:\(id)"
        case .saveGuardian(let value): "guardian:\(value.id)"
        case .deleteGuardian(let id): "guardian:\(id)"
        case .saveEnrollment(let value): "enrollment:\(value.id)"
        case .deleteEnrollment(let id): "enrollment:\(id)"
        case .saveAttendance(let value): "attendance:\(value.id)"
        case .deleteAttendance(let id): "attendance:\(id)"
        case .saveLeaveRequest(let value): "leave-request:\(value.id)"
        case .deleteLeaveRequest(let id): "leave-request:\(id)"
        case .deleteContractDocument(let id, _): "contract-document:\(id)"
        case .saveContractConsent(let value): "contract-consent:\(value.id)"
        case .saveNotification(let value): "notification:\(value.id)"
        }
    }

    func apply(to repository: any MasterDanceRepository) async throws {
        switch self {
        case .saveTerm(let value): try await repository.save(term: value)
        case .deleteTerm(let id): try await repository.deleteTerm(id: id)
        case .saveTermHoliday(let value): try await repository.save(termHoliday: value)
        case .deleteTermHoliday(let id): try await repository.deleteTermHoliday(id: id)
        case .saveCourseCategory(let value): try await repository.save(courseCategory: value)
        case .deleteCourseCategory(let id): try await repository.deleteCourseCategory(id: id)
        case .saveCourseType(let value): try await repository.save(courseType: value)
        case .deleteCourseType(let id): try await repository.deleteCourseType(id: id)
        case .saveAgeGroup(let value): try await repository.save(ageGroup: value)
        case .deleteAgeGroup(let id): try await repository.deleteAgeGroup(id: id)
        case .saveRoom(let value): try await repository.save(room: value)
        case .deleteRoom(let id): try await repository.deleteRoom(id: id)
        case .saveInstructor(let value): try await repository.save(instructor: value)
        case .deleteInstructor(let id): try await repository.deleteInstructor(id: id)
        case .saveCourse(let value): try await repository.save(course: value)
        case .deleteCourse(let id): try await repository.deleteCourse(id: id)
        case .saveSession(let value): try await repository.save(session: value)
        case .deleteSession(let id): try await repository.deleteSession(id: id)
        case .saveStudent(let value): try await repository.save(student: value)
        case .createStudent(let value, let guardianID):
            _ = try await repository.create(student: value, for: guardianID)
        case .linkStudent(let studentID, let guardianID):
            try await repository.link(studentID: studentID, to: guardianID)
        case .deleteStudent(let id): try await repository.deleteStudent(id: id)
        case .saveGuardian(let value): try await repository.save(guardian: value)
        case .deleteGuardian(let id): try await repository.deleteGuardian(id: id)
        case .saveEnrollment(let value): try await repository.save(enrollment: value)
        case .deleteEnrollment(let id): try await repository.deleteEnrollment(id: id)
        case .saveAttendance(let value): try await repository.save(attendance: value)
        case .deleteAttendance(let id): try await repository.deleteAttendance(id: id)
        case .saveLeaveRequest(let value): try await repository.save(leaveRequest: value)
        case .deleteLeaveRequest(let id): try await repository.deleteLeaveRequest(id: id)
        case .deleteContractDocument(let id, let storagePath):
            try await repository.deleteContractDocument(id: id, storagePath: storagePath)
        case .saveContractConsent(let value): try await repository.save(contractConsent: value)
        case .saveNotification(let value): try await repository.save(notification: value)
        }
    }
}
