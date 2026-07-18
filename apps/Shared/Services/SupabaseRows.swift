import Foundation
import MasterDanceCore

struct ProfileRow: Codable, Sendable {
    let userID: UUID
    let organizationID: UUID
    let role: String
    let displayName: String
    let appearance: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case organizationID = "organization_id"
        case role
        case displayName = "display_name"
        case appearance
        case isActive = "is_active"
    }
}

struct TermRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let startsOn: String
    let endsOn: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case status
    }

    init(_ term: Term, organizationID: UUID) {
        id = term.id.rawValue
        self.organizationID = organizationID
        name = term.name
        startsOn = SupabaseDateCodec.dayString(from: term.startsOn)
        endsOn = SupabaseDateCodec.dayString(from: term.endsOn)
        status = term.status.rawValue
    }

    func domain() throws -> Term {
        guard let status = TermStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "学期状态", value: status)
        }
        return try Term(
            id: TermID(serverID: id),
            name: name,
            startsOn: SupabaseDateCodec.date(from: startsOn),
            endsOn: SupabaseDateCodec.date(from: endsOn),
            status: status
        )
    }
}

struct CourseCategoryRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case isActive = "is_active"
    }

    init(_ category: CourseCategory, organizationID: UUID) {
        id = category.id.rawValue
        self.organizationID = organizationID
        name = category.name
        isActive = category.isActive
    }

    func domain() -> CourseCategory {
        CourseCategory(id: CourseCategoryID(serverID: id), name: name, isActive: isActive)
    }
}

struct AgeGroupRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case notes
        case isActive = "is_active"
    }

    init(_ ageGroup: AgeGroup, organizationID: UUID) {
        id = ageGroup.id.rawValue
        self.organizationID = organizationID
        name = ageGroup.name
        notes = ageGroup.notes
        isActive = ageGroup.isActive
    }

    func domain() -> AgeGroup {
        AgeGroup(id: AgeGroupID(serverID: id), name: name, notes: notes, isActive: isActive)
    }
}

struct RoomRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case isActive = "is_active"
    }

    init(_ room: Room, organizationID: UUID) {
        id = room.id.rawValue
        self.organizationID = organizationID
        name = room.name
        isActive = room.isActive
    }

    func domain() -> Room {
        Room(id: RoomID(serverID: id), name: name, isActive: isActive)
    }
}

struct InstructorRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let displayName: String
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case displayName = "display_name"
        case notes
        case isActive = "is_active"
    }

    init(_ instructor: Instructor, organizationID: UUID) {
        id = instructor.id.rawValue
        self.organizationID = organizationID
        displayName = instructor.displayName
        notes = instructor.notes
        isActive = instructor.isActive
    }

    func domain() -> Instructor {
        Instructor(
            id: InstructorID(serverID: id),
            displayName: displayName,
            notes: notes,
            isActive: isActive
        )
    }
}

struct CourseRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let termID: UUID
    let name: String
    let categoryID: UUID
    let ageGroupID: UUID
    let defaultRoomID: UUID
    let defaultInstructorID: UUID
    let format: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case name
        case categoryID = "category_id"
        case ageGroupID = "age_group_id"
        case defaultRoomID = "default_room_id"
        case defaultInstructorID = "default_instructor_id"
        case format
        case notes
    }

    init(_ course: Course, organizationID: UUID) {
        id = course.id.rawValue
        self.organizationID = organizationID
        termID = course.termID.rawValue
        name = course.name
        categoryID = course.categoryID.rawValue
        ageGroupID = course.ageGroupID.rawValue
        defaultRoomID = course.defaultRoomID.rawValue
        defaultInstructorID = course.defaultInstructorID.rawValue
        format = course.format == .privateLesson ? "private_lesson" : "group"
        notes = course.notes
    }

    func domain() throws -> Course {
        let domainFormat: CourseFormat
        switch format {
        case "group": domainFormat = .group
        case "private_lesson": domainFormat = .privateLesson
        default: throw SupabaseRepositoryError.invalidValue(field: "课程形式", value: format)
        }

        return Course(
            id: CourseID(serverID: id),
            termID: TermID(serverID: termID),
            name: name,
            categoryID: CourseCategoryID(serverID: categoryID),
            ageGroupID: AgeGroupID(serverID: ageGroupID),
            defaultRoomID: RoomID(serverID: defaultRoomID),
            defaultInstructorID: InstructorID(serverID: defaultInstructorID),
            format: domainFormat,
            notes: notes
        )
    }
}

struct ClassSessionRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let courseID: UUID
    let startsAt: String
    let endsAt: String
    let instructorOverrideID: UUID?
    let roomOverrideID: UUID?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case courseID = "course_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case instructorOverrideID = "instructor_override_id"
        case roomOverrideID = "room_override_id"
        case status
    }

    init(_ session: ClassSession, organizationID: UUID) {
        id = session.id.rawValue
        self.organizationID = organizationID
        courseID = session.courseID.rawValue
        startsAt = SupabaseDateCodec.timestampString(from: session.startsAt)
        endsAt = SupabaseDateCodec.timestampString(from: session.endsAt)
        instructorOverrideID = session.instructorOverrideID?.rawValue
        roomOverrideID = session.roomOverrideID?.rawValue
        status = session.status.rawValue
    }

    func domain() throws -> ClassSession {
        guard let status = ClassSessionStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "课次状态", value: status)
        }
        return try ClassSession(
            id: ClassSessionID(serverID: id),
            courseID: CourseID(serverID: courseID),
            startsAt: SupabaseDateCodec.timestamp(from: startsAt),
            endsAt: SupabaseDateCodec.timestamp(from: endsAt),
            instructorOverrideID: instructorOverrideID.map(InstructorID.init(serverID:)),
            roomOverrideID: roomOverrideID.map(RoomID.init(serverID:)),
            status: status
        )
    }
}

struct StudentRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let displayName: String
    let legalName: String?
    let kind: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case displayName = "display_name"
        case legalName = "legal_name"
        case kind
        case isActive = "is_active"
    }

    init(_ student: Student, organizationID: UUID) {
        id = student.id.rawValue
        self.organizationID = organizationID
        displayName = student.displayName
        legalName = student.legalName
        kind = student.kind.rawValue
        isActive = student.isActive
    }

    func domain() throws -> Student {
        guard let kind = StudentKind(rawValue: kind) else {
            throw SupabaseRepositoryError.invalidValue(field: "学生类型", value: kind)
        }
        return Student(
            id: StudentID(serverID: id),
            displayName: displayName,
            legalName: legalName,
            kind: kind,
            isActive: isActive
        )
    }
}

struct GuardianRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let displayName: String
    let profileUserID: UUID?
    let email: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case displayName = "display_name"
        case profileUserID = "profile_user_id"
        case email
        case phone
    }

    init(_ guardian: Guardian, organizationID: UUID) {
        id = guardian.id.rawValue
        self.organizationID = organizationID
        displayName = guardian.displayName
        profileUserID = guardian.profileUserID
        email = guardian.email
        phone = guardian.phone
    }
}

struct GuardianLinkStatusRow: Decodable, Sendable {
    let guardianID: UUID
    let linkedUserID: UUID?
    let activeCodeHint: String?
    let activeCodeExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case guardianID = "guardian_id"
        case linkedUserID = "linked_user_id"
        case activeCodeHint = "active_code_hint"
        case activeCodeExpiresAt = "active_code_expires_at"
    }
}

struct GuardianLinkCodeRow: Decodable, Sendable {
    let guardianID: UUID
    let linkCode: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case guardianID = "guardian_id"
        case linkCode = "link_code"
        case expiresAt = "expires_at"
    }

    func domain() throws -> GuardianLinkCode {
        GuardianLinkCode(
            guardianID: GuardianID(serverID: guardianID),
            code: linkCode,
            expiresAt: try SupabaseDateCodec.timestamp(from: expiresAt)
        )
    }
}

struct CreateStudentForGuardianParameters: Encodable, Sendable {
    let guardianID: UUID
    let displayName: String
    let legalName: String?
    let kind: String

    enum CodingKeys: String, CodingKey {
        case guardianID = "target_guardian_id"
        case displayName = "target_display_name"
        case legalName = "target_legal_name"
        case kind = "target_kind"
    }
}

struct LinkStudentToGuardianParameters: Encodable, Sendable {
    let guardianID: UUID
    let studentID: UUID

    enum CodingKeys: String, CodingKey {
        case guardianID = "target_guardian_id"
        case studentID = "target_student_id"
    }
}

struct IssueGuardianLinkCodeParameters: Encodable, Sendable {
    let guardianID: UUID
    let validityDays: Int

    enum CodingKeys: String, CodingKey {
        case guardianID = "target_guardian_id"
        case validityDays = "validity_days"
    }
}

struct GuardianStudentRow: Codable, Sendable {
    let organizationID: UUID
    let guardianID: UUID
    let studentID: UUID
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case guardianID = "guardian_id"
        case studentID = "student_id"
        case isPrimary = "is_primary"
    }
}

struct EnrollmentRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let termID: UUID
    let courseID: UUID
    let studentID: UUID
    let enrolledAt: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case courseID = "course_id"
        case studentID = "student_id"
        case enrolledAt = "enrolled_at"
        case status
    }

    init(_ enrollment: Enrollment, organizationID: UUID) {
        id = enrollment.id.rawValue
        self.organizationID = organizationID
        termID = enrollment.termID.rawValue
        courseID = enrollment.courseID.rawValue
        studentID = enrollment.studentID.rawValue
        enrolledAt = SupabaseDateCodec.timestampString(from: enrollment.enrolledAt)
        status = enrollment.status.rawValue
    }

    func domain() throws -> Enrollment {
        guard let status = EnrollmentStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "报名状态", value: status)
        }
        return try Enrollment(
            id: EnrollmentID(serverID: id),
            termID: TermID(serverID: termID),
            courseID: CourseID(serverID: courseID),
            studentID: StudentID(serverID: studentID),
            enrolledAt: SupabaseDateCodec.timestamp(from: enrolledAt),
            status: status
        )
    }
}

struct AttendanceRecordRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let sessionID: UUID
    let studentID: UUID
    let enrollmentID: UUID?
    let status: String
    let recordedAt: String
    let recordedBy: UUID?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case sessionID = "session_id"
        case studentID = "student_id"
        case enrollmentID = "enrollment_id"
        case status
        case recordedAt = "recorded_at"
        case recordedBy = "recorded_by"
        case note
    }

    init(_ attendance: Attendance, organizationID: UUID, recordedBy: UUID?) {
        id = attendance.id.rawValue
        self.organizationID = organizationID
        sessionID = attendance.sessionID.rawValue
        studentID = attendance.studentID.rawValue
        enrollmentID = attendance.enrollmentID?.rawValue
        status = attendance.status.rawValue
        recordedAt = SupabaseDateCodec.timestampString(from: attendance.recordedAt)
        self.recordedBy = recordedBy
        note = attendance.note
    }

    func domain() throws -> Attendance {
        guard let status = AttendanceStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "签到状态", value: status)
        }
        return try Attendance(
            id: AttendanceID(serverID: id),
            sessionID: ClassSessionID(serverID: sessionID),
            studentID: StudentID(serverID: studentID),
            enrollmentID: enrollmentID.map(EnrollmentID.init(serverID:)),
            status: status,
            recordedAt: SupabaseDateCodec.timestamp(from: recordedAt),
            note: note
        )
    }
}

struct LeaveRequestRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let sessionID: UUID
    let studentID: UUID
    let enrollmentID: UUID?
    let source: String
    let status: String
    let submittedAt: String
    let submittedBy: UUID?
    let resolvedAt: String?
    let resolvedBy: UUID?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case sessionID = "session_id"
        case studentID = "student_id"
        case enrollmentID = "enrollment_id"
        case source
        case status
        case submittedAt = "submitted_at"
        case submittedBy = "submitted_by"
        case resolvedAt = "resolved_at"
        case resolvedBy = "resolved_by"
        case note
    }

    init(
        _ request: LeaveRequest,
        organizationID: UUID,
        submittedBy: UUID?,
        resolvedBy: UUID?
    ) {
        id = request.id.rawValue
        self.organizationID = organizationID
        sessionID = request.sessionID.rawValue
        studentID = request.studentID.rawValue
        enrollmentID = request.enrollmentID?.rawValue
        source = request.source.rawValue
        status = request.status.rawValue
        submittedAt = SupabaseDateCodec.timestampString(from: request.submittedAt)
        self.submittedBy = submittedBy
        resolvedAt = request.resolvedAt.map(SupabaseDateCodec.timestampString(from:))
        self.resolvedBy = resolvedBy
        note = request.note
    }

    func domain() throws -> LeaveRequest {
        guard let source = LeaveRequestSource(rawValue: source) else {
            throw SupabaseRepositoryError.invalidValue(field: "请假来源", value: source)
        }
        guard let status = LeaveRequestStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "请假状态", value: status)
        }
        return try LeaveRequest(
            id: LeaveRequestID(serverID: id),
            sessionID: ClassSessionID(serverID: sessionID),
            studentID: StudentID(serverID: studentID),
            enrollmentID: enrollmentID.map(EnrollmentID.init(serverID:)),
            source: source,
            status: status,
            submittedAt: SupabaseDateCodec.timestamp(from: submittedAt),
            resolvedAt: resolvedAt.map { try SupabaseDateCodec.timestamp(from: $0) },
            note: note
        )
    }
}

struct ContractDocumentSummaryRow: Codable, Sendable {
    let id: UUID
    let version: String
}

struct ContractConsentRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let contractDocumentID: UUID
    let termID: UUID
    let enrollmentID: UUID?
    let signerKind: String
    let signerDisplayName: String
    let consentedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case contractDocumentID = "contract_document_id"
        case termID = "term_id"
        case enrollmentID = "enrollment_id"
        case signerKind = "signer_kind"
        case signerDisplayName = "signer_display_name"
        case consentedAt = "consented_at"
    }

    func domain(contractVersion: String) throws -> ContractConsent {
        let signer: ConsentSignerKind
        switch signerKind {
        case "guardian": signer = .guardian
        case "adult_student": signer = .adultStudent
        default: throw SupabaseRepositoryError.invalidValue(field: "签署人类型", value: signerKind)
        }
        return try ContractConsent(
            id: ContractConsentID(serverID: id),
            termID: TermID(serverID: termID),
            enrollmentID: enrollmentID.map(EnrollmentID.init(serverID:)),
            contractVersion: contractVersion,
            signerKind: signer,
            signerDisplayName: signerDisplayName,
            consentedAt: SupabaseDateCodec.timestamp(from: consentedAt)
        )
    }
}

struct ContractConsentInsertRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let contractDocumentID: UUID
    let termID: UUID
    let enrollmentID: UUID?
    let scope: String
    let signerUserID: UUID
    let signerKind: String
    let signerDisplayName: String
    let consentedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case contractDocumentID = "contract_document_id"
        case termID = "term_id"
        case enrollmentID = "enrollment_id"
        case scope
        case signerUserID = "signer_user_id"
        case signerKind = "signer_kind"
        case signerDisplayName = "signer_display_name"
        case consentedAt = "consented_at"
    }
}

struct NotificationRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let recipientUserID: UUID
    let kind: String
    let channel: String
    let title: String
    let body: String
    let scheduledAt: String?
    let sentAt: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case recipientUserID = "recipient_user_id"
        case kind
        case channel
        case title
        case body
        case scheduledAt = "scheduled_at"
        case sentAt = "sent_at"
        case status
    }

    init(_ notification: NotificationRecord, organizationID: UUID) throws {
        guard let recipient = UUID(uuidString: notification.recipientReference) else {
            throw SupabaseRepositoryError.invalidValue(
                field: "通知收件人",
                value: notification.recipientReference
            )
        }
        id = notification.id.rawValue
        self.organizationID = organizationID
        recipientUserID = recipient
        kind = switch notification.kind {
        case .classReminder: "class_reminder"
        case .leaveSubmitted: "leave_submitted"
        case .leaveResolved: "leave_resolved"
        case .contractAvailable: "contract_available"
        }
        channel = notification.channel == .applePush ? "apple_push" : "in_app"
        title = notification.title
        body = notification.body
        scheduledAt = notification.scheduledAt.map(SupabaseDateCodec.timestampString(from:))
        sentAt = notification.sentAt.map(SupabaseDateCodec.timestampString(from:))
        status = notification.status.rawValue
    }

    func domain() throws -> NotificationRecord {
        let kind: NotificationKind
        switch self.kind {
        case "class_reminder": kind = .classReminder
        case "leave_submitted": kind = .leaveSubmitted
        case "leave_resolved": kind = .leaveResolved
        case "contract_available": kind = .contractAvailable
        default: throw SupabaseRepositoryError.invalidValue(field: "通知类型", value: self.kind)
        }
        let channel: NotificationChannel
        switch self.channel {
        case "in_app": channel = .inApp
        case "apple_push": channel = .applePush
        default: throw SupabaseRepositoryError.invalidValue(field: "通知渠道", value: self.channel)
        }
        guard let status = NotificationDeliveryStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "通知状态", value: status)
        }
        return try NotificationRecord(
            id: NotificationRecordID(serverID: id),
            recipientReference: recipientUserID.uuidString,
            kind: kind,
            channel: channel,
            title: title,
            body: body,
            scheduledAt: scheduledAt.map { try SupabaseDateCodec.timestamp(from: $0) },
            sentAt: sentAt.map { try SupabaseDateCodec.timestamp(from: $0) },
            status: status
        )
    }
}
