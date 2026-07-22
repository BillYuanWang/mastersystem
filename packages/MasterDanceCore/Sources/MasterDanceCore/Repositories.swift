import Foundation

public protocol TermRepository: Sendable {
    func listTerms() async throws -> [Term]
    func save(term: Term) async throws
    func deleteTerm(id: TermID) async throws
    func listTermHolidays(termID: TermID?) async throws -> [TermHoliday]
    func save(termHoliday: TermHoliday) async throws
    func deleteTermHoliday(id: TermHolidayID) async throws
}

public protocol CourseReferenceRepository: Sendable {
    func listCourseCategories() async throws -> [CourseCategory]
    func listCourseTypes() async throws -> [CourseType]
    func listAgeGroups() async throws -> [AgeGroup]
    func listRooms() async throws -> [Room]
    func listInstructors() async throws -> [Instructor]
    func save(courseCategory: CourseCategory) async throws
    func save(courseType: CourseType) async throws
    func save(ageGroup: AgeGroup) async throws
    func save(room: Room) async throws
    func save(instructor: Instructor) async throws
    func deleteCourseCategory(id: CourseCategoryID) async throws
    func deleteCourseType(id: CourseTypeID) async throws
    func deleteAgeGroup(id: AgeGroupID) async throws
    func deleteRoom(id: RoomID) async throws
    func deleteInstructor(id: InstructorID) async throws
}

public protocol CourseRepository: Sendable {
    func listCourses(termID: TermID?) async throws -> [Course]
    func save(course: Course) async throws
    func deleteCourse(id: CourseID) async throws
}

public protocol ClassSessionRepository: Sendable {
    func listSessions(courseID: CourseID?) async throws -> [ClassSession]
    func save(session: ClassSession) async throws
    func deleteSession(id: ClassSessionID) async throws
}

public protocol PeopleRepository: Sendable {
    func listStudents() async throws -> [Student]
    func listGuardians(studentID: StudentID?) async throws -> [Guardian]
    func save(student: Student) async throws
    func save(guardian: Guardian) async throws
    func create(student: Student, for guardianID: GuardianID) async throws -> Student
    func link(studentID: StudentID, to guardianID: GuardianID) async throws
    func issueGuardianLinkCode(guardianID: GuardianID) async throws -> GuardianLinkCode
    func deleteStudent(id: StudentID) async throws
    func deleteGuardian(id: GuardianID) async throws
}

public protocol EnrollmentRepository: Sendable {
    func listEnrollments(termID: TermID?, courseID: CourseID?, studentID: StudentID?) async throws -> [Enrollment]
    func save(enrollment: Enrollment) async throws
    func deleteEnrollment(id: EnrollmentID) async throws
}

public protocol AttendanceRepository: Sendable {
    func listAttendance(sessionID: ClassSessionID?, studentID: StudentID?) async throws -> [Attendance]
    func save(attendance: Attendance) async throws
    func deleteAttendance(id: AttendanceID) async throws
}

public protocol LeaveRequestRepository: Sendable {
    func listLeaveRequests(sessionID: ClassSessionID?, studentID: StudentID?) async throws -> [LeaveRequest]
    func save(leaveRequest: LeaveRequest) async throws
    func deleteLeaveRequest(id: LeaveRequestID) async throws
}

public protocol ContractDocumentRepository: Sendable {
    func listContractDocuments(termID: TermID?) async throws -> [ContractDocument]
    func save(contractDocument: ContractDocument, fileData: Data?) async throws -> ContractDocument
    func publishContractRevision(
        termID: TermID,
        title: String,
        bodyText: String
    ) async throws -> ContractDocument
    func deleteContractDocument(id: ContractDocumentID, storagePath: String) async throws
}

public protocol ContractConsentRepository: Sendable {
    func listContractConsents(termID: TermID, enrollmentID: EnrollmentID?) async throws -> [ContractConsent]
    func save(contractConsent: ContractConsent) async throws
}

public protocol NewsRepository: Sendable {
    func listNewsArticles() async throws -> [NewsArticle]
    func listNewsArticleImages(articleID: NewsArticleID?) async throws -> [NewsArticleImage]
    func save(newsArticle: NewsArticle) async throws -> NewsArticle
    func save(newsArticleImage: NewsArticleImage, fileData: Data?) async throws -> NewsArticleImage
    func deleteNewsArticle(id: NewsArticleID) async throws
    func deleteNewsArticleImage(id: NewsArticleImageID, storagePath: String) async throws
    func newsMediaData(storagePath: String) async throws -> Data
}

public protocol AdvertisementRepository: Sendable {
    func listAdvertisements() async throws -> [Advertisement]
    func save(
        advertisement: Advertisement,
        thumbnailData: Data?,
        posterData: Data?
    ) async throws -> Advertisement
    func deleteAdvertisement(id: AdvertisementID) async throws
    func advertisementMediaData(storagePath: String) async throws -> Data
}

public protocol NotificationRepository: Sendable {
    func listNotifications(recipientReference: String?) async throws -> [NotificationRecord]
    func save(notification: NotificationRecord) async throws
}

public protocol BillingRepository: Sendable {
    func listBillingInvoices(guardianID: GuardianID?) async throws -> [BillingInvoice]
    func listBillingInvoiceLineItems(invoiceID: BillingInvoiceID?) async throws -> [BillingInvoiceLineItem]
    func listBillingPayments(invoiceID: BillingInvoiceID?) async throws -> [BillingPayment]
    func listBillingArtifacts(invoiceID: BillingInvoiceID?) async throws -> [BillingArtifact]
    func issueBillingInvoice(
        invoice: BillingInvoice,
        lineItems: [BillingInvoiceLineItem],
        artifact: BillingArtifact,
        pngData: Data
    ) async throws -> BillingInvoice
    func recordBillingPayment(
        payment: BillingPayment,
        artifact: BillingArtifact,
        pngData: Data
    ) async throws -> BillingPayment
    func billingArtifactData(storagePath: String) async throws -> Data
}

public typealias MasterDanceRepository = TermRepository
    & CourseReferenceRepository
    & CourseRepository
    & ClassSessionRepository
    & PeopleRepository
    & EnrollmentRepository
    & AttendanceRepository
    & LeaveRequestRepository
    & ContractDocumentRepository
    & ContractConsentRepository
    & NewsRepository
    & AdvertisementRepository
    & NotificationRepository
    & BillingRepository
