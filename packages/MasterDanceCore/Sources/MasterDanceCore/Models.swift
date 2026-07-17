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
    public let termID: TermID
    public var name: String
    public var categoryID: CourseCategoryID
    public var ageGroupID: AgeGroupID
    public var defaultRoomID: RoomID
    public var defaultInstructorID: InstructorID
    public var format: CourseFormat
    public var notes: String?

    public init(
        id: CourseID = CourseID(),
        termID: TermID,
        name: String,
        categoryID: CourseCategoryID,
        ageGroupID: AgeGroupID,
        defaultRoomID: RoomID,
        defaultInstructorID: InstructorID,
        format: CourseFormat,
        notes: String? = nil
    ) {
        self.id = id
        self.termID = termID
        self.name = name
        self.categoryID = categoryID
        self.ageGroupID = ageGroupID
        self.defaultRoomID = defaultRoomID
        self.defaultInstructorID = defaultInstructorID
        self.format = format
        self.notes = notes
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
    public var displayName: String
    public var legalName: String?
    public var kind: StudentKind
    public var isActive: Bool

    public init(
        id: StudentID = StudentID(),
        displayName: String,
        legalName: String? = nil,
        kind: StudentKind,
        isActive: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.legalName = legalName
        self.kind = kind
        self.isActive = isActive
    }
}

public struct Guardian: Identifiable, Codable, Equatable, Sendable {
    public let id: GuardianID
    public var displayName: String
    public var email: String?
    public var phone: String?
    public var studentIDs: Set<StudentID>

    public init(
        id: GuardianID = GuardianID(),
        displayName: String,
        email: String? = nil,
        phone: String? = nil,
        studentIDs: Set<StudentID> = []
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.studentIDs = studentIDs
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
    public let sessionID: ClassSessionID
    public let studentID: StudentID
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
        status: LeaveRequestStatus = .pending,
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

public enum ConsentSignerKind: String, Codable, CaseIterable, Sendable {
    case guardian
    case adultStudent
}

public struct ContractConsent: Identifiable, Codable, Equatable, Sendable {
    public let id: ContractConsentID
    public let termID: TermID
    public var enrollmentID: EnrollmentID?
    public var contractVersion: String
    public var signerKind: ConsentSignerKind
    public var signerDisplayName: String
    public var consentedAt: Date

    public init(
        id: ContractConsentID = ContractConsentID(),
        termID: TermID,
        enrollmentID: EnrollmentID? = nil,
        contractVersion: String,
        signerKind: ConsentSignerKind,
        signerDisplayName: String,
        consentedAt: Date
    ) {
        self.id = id
        self.termID = termID
        self.enrollmentID = enrollmentID
        self.contractVersion = contractVersion
        self.signerKind = signerKind
        self.signerDisplayName = signerDisplayName
        self.consentedAt = consentedAt
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
