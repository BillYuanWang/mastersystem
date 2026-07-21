import Foundation

public enum TermStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case open
    case closed
}

public struct Term: Identifiable, Codable, Equatable, Sendable {
    public let id: TermID
    public var name: String
    public var startsOn: Date
    public var endsOn: Date
    public var status: TermStatus

    public init(id: TermID = TermID(), name: String, startsOn: Date, endsOn: Date, status: TermStatus) {
        self.id = id
        self.name = name
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.status = status
    }
}

public struct TermHoliday: Identifiable, Codable, Equatable, Sendable {
    public let id: TermHolidayID
    public var termID: TermID
    public var name: String
    public var startsOn: Date
    public var endsOn: Date
    public var notes: String?

    public init(
        id: TermHolidayID = TermHolidayID(),
        termID: TermID,
        name: String,
        startsOn: Date,
        endsOn: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.termID = termID
        self.name = name
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.notes = notes
    }
}

public struct CourseCategory: Identifiable, Codable, Equatable, Sendable {
    public let id: CourseCategoryID
    public var name: String
    public var isActive: Bool

    public init(id: CourseCategoryID = CourseCategoryID(), name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct CourseType: Identifiable, Codable, Equatable, Sendable {
    public let id: CourseTypeID
    public var name: String
    public var isPrivate: Bool
    public var notes: String?
    public var isActive: Bool

    public init(
        id: CourseTypeID = CourseTypeID(),
        name: String,
        isPrivate: Bool,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isPrivate = isPrivate
        self.notes = notes
        self.isActive = isActive
    }
}

public struct AgeGroup: Identifiable, Codable, Equatable, Sendable {
    public let id: AgeGroupID
    public var name: String
    public var notes: String?
    public var isActive: Bool

    public init(id: AgeGroupID = AgeGroupID(), name: String, notes: String? = nil, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isActive = isActive
    }
}

public struct Room: Identifiable, Codable, Equatable, Sendable {
    public let id: RoomID
    public var name: String
    public var isActive: Bool

    public init(id: RoomID = RoomID(), name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct Instructor: Identifiable, Codable, Equatable, Sendable {
    public let id: InstructorID
    public var displayName: String
    public var notes: String?
    public var isActive: Bool

    public init(id: InstructorID = InstructorID(), displayName: String, notes: String? = nil, isActive: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.notes = notes
        self.isActive = isActive
    }
}

public enum CourseFormat: String, Codable, CaseIterable, Sendable {
    case group
    case privateLesson
}

public struct Course: Identifiable, Codable, Equatable, Sendable {
    public let id: CourseID
    public var termID: TermID
    public var name: String
    public var categoryID: CourseCategoryID
    public var ageGroupID: AgeGroupID
    public var defaultRoomID: RoomID
    public var defaultInstructorID: InstructorID
    public var courseTypeID: CourseTypeID
    public var format: CourseFormat
    public var notes: String?
    public var isActive: Bool

    public init(
        id: CourseID = CourseID(),
        termID: TermID,
        name: String,
        categoryID: CourseCategoryID,
        ageGroupID: AgeGroupID,
        defaultRoomID: RoomID,
        defaultInstructorID: InstructorID,
        courseTypeID: CourseTypeID,
        format: CourseFormat,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.termID = termID
        self.name = name
        self.categoryID = categoryID
        self.ageGroupID = ageGroupID
        self.defaultRoomID = defaultRoomID
        self.defaultInstructorID = defaultInstructorID
        self.courseTypeID = courseTypeID
        self.format = format
        self.notes = notes
        self.isActive = isActive
    }
}

public enum ClassSessionStatus: String, Codable, CaseIterable, Sendable {
    case scheduled
    case cancelled
    case completed
}

public struct ClassSession: Identifiable, Codable, Equatable, Sendable {
    public let id: ClassSessionID
    public let courseID: CourseID
    public var startsAt: Date
    public var endsAt: Date
    public var instructorOverrideID: InstructorID?
    public var roomOverrideID: RoomID?
    public var status: ClassSessionStatus

    public init(
        id: ClassSessionID = ClassSessionID(),
        courseID: CourseID,
        startsAt: Date,
        endsAt: Date,
        instructorOverrideID: InstructorID? = nil,
        roomOverrideID: RoomID? = nil,
        status: ClassSessionStatus = .scheduled
    ) {
        self.id = id
        self.courseID = courseID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.instructorOverrideID = instructorOverrideID
        self.roomOverrideID = roomOverrideID
        self.status = status
    }
}

public enum StudentKind: String, Codable, CaseIterable, Sendable {
    case child
    case adult
}

public struct Student: Identifiable, Codable, Equatable, Sendable {
    public let id: StudentID
    public var guardianID: GuardianID
    public var displayName: String
    public var legalName: String?
    public var birthDate: Date?
    public var kind: StudentKind
    public var isActive: Bool

    public init(
        id: StudentID = StudentID(),
        guardianID: GuardianID,
        displayName: String,
        legalName: String? = nil,
        birthDate: Date? = nil,
        kind: StudentKind,
        isActive: Bool = true
    ) {
        self.id = id
        self.guardianID = guardianID
        self.displayName = displayName
        self.legalName = legalName
        self.birthDate = birthDate
        self.kind = kind
        self.isActive = isActive
    }
}

public struct Guardian: Identifiable, Codable, Equatable, Sendable {
    public let id: GuardianID
    public var displayName: String
    public var email: String?
    public var phone: String?
    public var address: String?
    public var profileUserID: UUID?
    public var studentIDs: Set<StudentID>
    public var activeLinkCodeHint: String?
    public var activeLinkCodeExpiresAt: Date?

    public init(
        id: GuardianID = GuardianID(),
        displayName: String,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        profileUserID: UUID? = nil,
        studentIDs: Set<StudentID> = [],
        activeLinkCodeHint: String? = nil,
        activeLinkCodeExpiresAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.address = address
        self.profileUserID = profileUserID
        self.studentIDs = studentIDs
        self.activeLinkCodeHint = activeLinkCodeHint
        self.activeLinkCodeExpiresAt = activeLinkCodeExpiresAt
    }

    public var isAccountLinked: Bool {
        profileUserID != nil
    }
}

public struct GuardianLinkCode: Identifiable, Codable, Equatable, Sendable {
    public var id: GuardianID { guardianID }
    public let guardianID: GuardianID
    public let code: String
    public let expiresAt: Date

    public init(
        guardianID: GuardianID,
        code: String,
        expiresAt: Date
    ) {
        self.guardianID = guardianID
        self.code = code
        self.expiresAt = expiresAt
    }
}

public enum EnrollmentStatus: String, Codable, CaseIterable, Sendable {
    case active
    case withdrawn
    case completed
}

public struct Enrollment: Identifiable, Codable, Equatable, Sendable {
    public let id: EnrollmentID
    public let termID: TermID
    public let courseID: CourseID
    public let studentID: StudentID
    public var enrolledAt: Date
    public var status: EnrollmentStatus

    public init(
        id: EnrollmentID = EnrollmentID(),
        termID: TermID,
        courseID: CourseID,
        studentID: StudentID,
        enrolledAt: Date,
        status: EnrollmentStatus = .active
    ) {
        self.id = id
        self.termID = termID
        self.courseID = courseID
        self.studentID = studentID
        self.enrolledAt = enrolledAt
        self.status = status
    }
}

public enum AttendanceStatus: String, Codable, CaseIterable, Sendable {
    case present
    case absent
    case excused
    case makeup
    case trial

    public var isGuestAttendance: Bool {
        switch self {
        case .makeup, .trial: true
        case .present, .absent, .excused: false
        }
    }

    public var recordsPhysicalAttendance: Bool {
        switch self {
        case .present, .makeup, .trial: true
        case .absent, .excused: false
        }
    }
}

public struct Attendance: Identifiable, Codable, Equatable, Sendable {
    public let id: AttendanceID
    public let sessionID: ClassSessionID
    public let studentID: StudentID
    public var enrollmentID: EnrollmentID?
    public var status: AttendanceStatus
    public var recordedAt: Date
    public var note: String?

    public init(
        id: AttendanceID = AttendanceID(),
        sessionID: ClassSessionID,
        studentID: StudentID,
        enrollmentID: EnrollmentID? = nil,
        status: AttendanceStatus,
        recordedAt: Date,
        note: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.studentID = studentID
        self.enrollmentID = enrollmentID
        self.status = status
        self.recordedAt = recordedAt
        self.note = note
    }
}

public enum LeaveRequestSource: String, Codable, CaseIterable, Sendable {
    case app
    case administrator
}

public enum LeaveRequestStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case denied
    case late
}

public struct LeaveRequest: Identifiable, Codable, Equatable, Sendable {
    public let id: LeaveRequestID
    public var sessionID: ClassSessionID
    public var studentID: StudentID
    public var enrollmentID: EnrollmentID?
    public var source: LeaveRequestSource
    public var status: LeaveRequestStatus
    public var submittedAt: Date
    public var resolvedAt: Date?
    public var note: String?

    public init(
        id: LeaveRequestID = LeaveRequestID(),
        sessionID: ClassSessionID,
        studentID: StudentID,
        enrollmentID: EnrollmentID? = nil,
        source: LeaveRequestSource,
        status: LeaveRequestStatus = .approved,
        submittedAt: Date,
        resolvedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.studentID = studentID
        self.enrollmentID = enrollmentID
        self.source = source
        self.status = status
        self.submittedAt = submittedAt
        self.resolvedAt = resolvedAt
        self.note = note
    }
}

public enum ContractDocumentStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case published
    case retired
}

public struct ContractDocument: Identifiable, Codable, Equatable, Sendable {
    public let id: ContractDocumentID
    public var termID: TermID
    public var version: String
    public var title: String
    public var bodyText: String
    public var storagePath: String
    public var status: ContractDocumentStatus
    public var publishedAt: Date?

    public init(
        id: ContractDocumentID = ContractDocumentID(),
        termID: TermID,
        version: String,
        title: String,
        bodyText: String = "",
        storagePath: String = "",
        status: ContractDocumentStatus = .draft,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.termID = termID
        self.version = version
        self.title = title
        self.bodyText = bodyText
        self.storagePath = storagePath
        self.status = status
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case termID
        case version
        case title
        case bodyText
        case storagePath
        case status
        case publishedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ContractDocumentID.self, forKey: .id)
        termID = try container.decode(TermID.self, forKey: .termID)
        version = try container.decode(String.self, forKey: .version)
        title = try container.decode(String.self, forKey: .title)
        bodyText = try container.decodeIfPresent(String.self, forKey: .bodyText) ?? ""
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath) ?? ""
        status = try container.decode(ContractDocumentStatus.self, forKey: .status)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
    }
}

public enum ContractAgreementTemplate {
    public static let placeholderTitle = "Master Dance 学员服务协议（测试版）"

    public static let placeholderBody = """
    重要提示

    本协议仅用于 Master Dance 系统功能测试，不是最终法律文件。学校正式启用前，应由负责人审核并替换全部内容。

    1. 课程安排

    学校会根据学期计划安排课程、教室与授课老师。必要时，学校可以提前通知后调整课程时间、教室或授课老师。

    2. 学员出勤

    监护人应协助学员按时到课。迟到、缺席、请假、补课与试课记录以学校教务系统中的记录为准。

    3. 请假与补课

    请假应通过学校认可的方式提交。补课资格、可选课程和有效期限由学校当期规则决定。

    4. 健康与安全

    监护人应如实告知可能影响训练的健康情况，并确保学员遵守课堂安全要求和教师指导。

    5. 通知与联系

    学校可以通过 App、电子邮件、电话或其他已约定方式发送课程变动、签到和教务通知。

    6. 电子签署

    监护人在 App 中完成手写签名并点击“同意”后，表示已经阅读并接受当前显示版本。协议内容更新后，需要重新阅读并签署新版本。

    7. 测试声明

    当前文字为占位内容。请教务老师在正式使用前完成修改、审核和发布。
    """
}

public enum ConsentSignerKind: String, Codable, CaseIterable, Sendable {
    case guardian
    case adultStudent
}

public struct ContractConsent: Identifiable, Codable, Equatable, Sendable {
    public let id: ContractConsentID
    public let contractDocumentID: ContractDocumentID?
    public let termID: TermID
    public var enrollmentID: EnrollmentID?
    public var contractVersion: String
    public var signerKind: ConsentSignerKind
    public var signerDisplayName: String
    public var consentedAt: Date
    public var signaturePNG: Data?

    public init(
        id: ContractConsentID = ContractConsentID(),
        contractDocumentID: ContractDocumentID? = nil,
        termID: TermID,
        enrollmentID: EnrollmentID? = nil,
        contractVersion: String,
        signerKind: ConsentSignerKind,
        signerDisplayName: String,
        consentedAt: Date,
        signaturePNG: Data? = nil
    ) {
        self.id = id
        self.contractDocumentID = contractDocumentID
        self.termID = termID
        self.enrollmentID = enrollmentID
        self.contractVersion = contractVersion
        self.signerKind = signerKind
        self.signerDisplayName = signerDisplayName
        self.consentedAt = consentedAt
        self.signaturePNG = signaturePNG
    }
}

public enum NotificationKind: String, Codable, CaseIterable, Sendable {
    case classReminder
    case leaveSubmitted
    case leaveResolved
    case contractAvailable
}

public enum NotificationChannel: String, Codable, CaseIterable, Sendable {
    case inApp
    case applePush
}

public enum NotificationDeliveryStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case sent
    case failed
    case read
}

public struct NotificationRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: NotificationRecordID
    public var recipientReference: String
    public var kind: NotificationKind
    public var channel: NotificationChannel
    public var title: String
    public var body: String
    public var scheduledAt: Date?
    public var sentAt: Date?
    public var status: NotificationDeliveryStatus

    public init(
        id: NotificationRecordID = NotificationRecordID(),
        recipientReference: String,
        kind: NotificationKind,
        channel: NotificationChannel,
        title: String,
        body: String,
        scheduledAt: Date? = nil,
        sentAt: Date? = nil,
        status: NotificationDeliveryStatus = .pending
    ) {
        self.id = id
        self.recipientReference = recipientReference
        self.kind = kind
        self.channel = channel
        self.title = title
        self.body = body
        self.scheduledAt = scheduledAt
        self.sentAt = sentAt
        self.status = status
    }
}
