import Foundation
import MasterDanceCore

struct SyncRevisionRow: Decodable, Sendable {
    let changeSequence: Int64

    enum CodingKeys: String, CodingKey {
        case changeSequence = "change_sequence"
    }
}

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

struct TermHolidayRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let termID: UUID
    let name: String
    let startsOn: String
    let endsOn: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case notes
    }

    init(_ holiday: TermHoliday, organizationID: UUID) {
        id = holiday.id.rawValue
        self.organizationID = organizationID
        termID = holiday.termID.rawValue
        name = holiday.name
        startsOn = SupabaseDateCodec.dayString(from: holiday.startsOn)
        endsOn = SupabaseDateCodec.dayString(from: holiday.endsOn)
        notes = holiday.notes
    }

    func domain() throws -> TermHoliday {
        try TermHoliday(
            id: TermHolidayID(serverID: id),
            termID: TermID(serverID: termID),
            name: name,
            startsOn: SupabaseDateCodec.date(from: startsOn),
            endsOn: SupabaseDateCodec.date(from: endsOn),
            notes: notes
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

struct CourseTypeRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let isPrivate: Bool
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case isPrivate = "is_private"
        case notes
        case isActive = "is_active"
    }

    init(_ courseType: CourseType, organizationID: UUID) {
        id = courseType.id.rawValue
        self.organizationID = organizationID
        name = courseType.name
        isPrivate = courseType.isPrivate
        notes = courseType.notes
        isActive = courseType.isActive
    }

    func domain() -> CourseType {
        CourseType(
            id: CourseTypeID(serverID: id),
            name: name,
            isPrivate: isPrivate,
            notes: notes,
            isActive: isActive
        )
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
    let courseTypeID: UUID
    let format: String
    let pricingStatus: String
    let unitPriceCents: Int?
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case name
        case categoryID = "category_id"
        case ageGroupID = "age_group_id"
        case defaultRoomID = "default_room_id"
        case defaultInstructorID = "default_instructor_id"
        case courseTypeID = "course_type_id"
        case format
        case pricingStatus = "pricing_status"
        case unitPriceCents = "unit_price_cents"
        case notes
        case isActive = "is_active"
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
        courseTypeID = course.courseTypeID.rawValue
        format = course.format == .privateLesson ? "private_lesson" : "group"
        pricingStatus = course.pricingStatus.rawValue
        unitPriceCents = course.unitPriceCents
        notes = course.notes
        isActive = course.isActive
    }

    func domain() throws -> Course {
        let domainFormat: CourseFormat
        switch format {
        case "group": domainFormat = .group
        case "private_lesson": domainFormat = .privateLesson
        default: throw SupabaseRepositoryError.invalidValue(field: "课程形式", value: format)
        }
        guard let domainPricingStatus = CoursePricingStatus(rawValue: pricingStatus) else {
            throw SupabaseRepositoryError.invalidValue(field: "课程定价状态", value: pricingStatus)
        }

        return Course(
            id: CourseID(serverID: id),
            termID: TermID(serverID: termID),
            name: name,
            categoryID: CourseCategoryID(serverID: categoryID),
            ageGroupID: AgeGroupID(serverID: ageGroupID),
            defaultRoomID: RoomID(serverID: defaultRoomID),
            defaultInstructorID: InstructorID(serverID: defaultInstructorID),
            courseTypeID: CourseTypeID(serverID: courseTypeID),
            format: domainFormat,
            pricingStatus: domainPricingStatus,
            unitPriceCents: unitPriceCents,
            notes: notes,
            isActive: isActive
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
    let guardianID: UUID
    let displayName: String
    let legalName: String?
    let birthDate: String?
    let kind: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case guardianID = "guardian_id"
        case displayName = "display_name"
        case legalName = "legal_name"
        case birthDate = "birth_date"
        case kind
        case isActive = "is_active"
    }

    init(_ student: Student, organizationID: UUID) {
        id = student.id.rawValue
        self.organizationID = organizationID
        guardianID = student.guardianID.rawValue
        displayName = student.displayName
        legalName = student.legalName
        birthDate = student.birthDate.map(SupabaseDateCodec.dayString(from:))
        kind = student.kind.rawValue
        isActive = student.isActive
    }

    func domain() throws -> Student {
        guard let kind = StudentKind(rawValue: kind) else {
            throw SupabaseRepositoryError.invalidValue(field: "学生类型", value: kind)
        }
        return Student(
            id: StudentID(serverID: id),
            guardianID: GuardianID(serverID: guardianID),
            displayName: displayName,
            legalName: legalName,
            birthDate: try birthDate.map(SupabaseDateCodec.date(from:)),
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
    let secondaryEmail: String?
    let phone: String?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case displayName = "display_name"
        case profileUserID = "profile_user_id"
        case email
        case secondaryEmail = "secondary_email"
        case phone
        case address
    }

    init(_ guardian: Guardian, organizationID: UUID) {
        id = guardian.id.rawValue
        self.organizationID = organizationID
        displayName = guardian.displayName
        profileUserID = guardian.profileUserID
        email = guardian.email
        secondaryEmail = guardian.secondaryEmail
        phone = guardian.phone
        address = guardian.address
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
    let birthDate: String?

    enum CodingKeys: String, CodingKey {
        case guardianID = "target_guardian_id"
        case displayName = "target_display_name"
        case legalName = "target_legal_name"
        case kind = "target_kind"
        case birthDate = "target_birth_date"
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

struct AdminDeleteRecordParameters: Encodable, Sendable {
    let kind: String
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case kind = "target_kind"
        case id = "target_id"
    }
}

struct AdminDeleteGuardianHouseholdParameters: Encodable, Sendable {
    let guardianID: UUID

    enum CodingKeys: String, CodingKey {
        case guardianID = "target_guardian_id"
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
    let pricingStatus: String
    let billingStartsOn: String?
    let unitPriceCents: Int?
    let trialFeeCents: Int
    let discountName: String?
    let discountKind: String?
    let discountValue: Int?
    let billingNotes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case courseID = "course_id"
        case studentID = "student_id"
        case enrolledAt = "enrolled_at"
        case status
        case pricingStatus = "pricing_status"
        case billingStartsOn = "billing_starts_on"
        case unitPriceCents = "unit_price_cents"
        case trialFeeCents = "trial_fee_cents"
        case discountName = "discount_name"
        case discountKind = "discount_kind"
        case discountValue = "discount_value"
        case billingNotes = "billing_notes"
    }

    init(_ enrollment: Enrollment, organizationID: UUID) {
        id = enrollment.id.rawValue
        self.organizationID = organizationID
        termID = enrollment.termID.rawValue
        courseID = enrollment.courseID.rawValue
        studentID = enrollment.studentID.rawValue
        enrolledAt = SupabaseDateCodec.timestampString(from: enrollment.enrolledAt)
        status = enrollment.status.rawValue
        pricingStatus = enrollment.pricingStatus.rawValue
        billingStartsOn = enrollment.billingStartsOn.map(SupabaseDateCodec.dayString(from:))
        unitPriceCents = enrollment.unitPriceCents
        trialFeeCents = enrollment.trialFeeCents
        discountName = enrollment.discountName
        discountKind = enrollment.discountKind?.rawValue
        discountValue = enrollment.discountValue
        billingNotes = enrollment.billingNotes
    }

    func domain() throws -> Enrollment {
        guard let status = EnrollmentStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "报名状态", value: status)
        }
        guard let domainPricingStatus = EnrollmentPricingStatus(rawValue: pricingStatus) else {
            throw SupabaseRepositoryError.invalidValue(field: "报名定价状态", value: pricingStatus)
        }
        let domainDiscountKind: BillingDiscountKind?
        if let discountKind {
            guard let value = BillingDiscountKind(rawValue: discountKind) else {
                throw SupabaseRepositoryError.invalidValue(field: "折扣种类", value: discountKind)
            }
            domainDiscountKind = value
        } else {
            domainDiscountKind = nil
        }
        return try Enrollment(
            id: EnrollmentID(serverID: id),
            termID: TermID(serverID: termID),
            courseID: CourseID(serverID: courseID),
            studentID: StudentID(serverID: studentID),
            enrolledAt: SupabaseDateCodec.timestamp(from: enrolledAt),
            status: status,
            pricingStatus: domainPricingStatus,
            billingStartsOn: try billingStartsOn.map(SupabaseDateCodec.date(from:)),
            unitPriceCents: unitPriceCents,
            trialFeeCents: trialFeeCents,
            discountName: discountName,
            discountKind: domainDiscountKind,
            discountValue: discountValue,
            billingNotes: billingNotes
        )
    }
}

struct AttendanceRecordRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let sessionID: UUID
    let studentID: UUID
    let enrollmentID: UUID?
    let makeupForSessionID: UUID?
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
        case makeupForSessionID = "makeup_for_session_id"
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
        makeupForSessionID = attendance.makeupForSessionID?.rawValue
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
            makeupForSessionID: makeupForSessionID.map(ClassSessionID.init(serverID:)),
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

struct ContractDocumentRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let termID: UUID
    let version: String
    let title: String
    let bodyText: String
    let storagePath: String
    let status: String
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case termID = "term_id"
        case version
        case title
        case bodyText = "body_text"
        case storagePath = "storage_path"
        case status
        case publishedAt = "published_at"
    }

    init(_ document: ContractDocument, organizationID: UUID) {
        id = document.id.rawValue
        self.organizationID = organizationID
        termID = document.termID.rawValue
        version = document.version
        title = document.title
        bodyText = document.bodyText
        storagePath = document.storagePath
        status = document.status.rawValue
        publishedAt = document.publishedAt.map(SupabaseDateCodec.timestampString(from:))
    }

    func domain() throws -> ContractDocument {
        guard let status = ContractDocumentStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "合同状态", value: status)
        }
        return try ContractDocument(
            id: ContractDocumentID(serverID: id),
            termID: TermID(serverID: termID),
            version: version,
            title: title,
            bodyText: bodyText,
            storagePath: storagePath,
            status: status,
            publishedAt: publishedAt.map { try SupabaseDateCodec.timestamp(from: $0) }
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

    func domain(contractVersion: String, signaturePNG: Data? = nil) throws -> ContractConsent {
        let signer: ConsentSignerKind
        switch signerKind {
        case "guardian": signer = .guardian
        case "adult_student": signer = .adultStudent
        default: throw SupabaseRepositoryError.invalidValue(field: "签署人类型", value: signerKind)
        }
        return try ContractConsent(
            id: ContractConsentID(serverID: id),
            contractDocumentID: ContractDocumentID(serverID: contractDocumentID),
            termID: TermID(serverID: termID),
            enrollmentID: enrollmentID.map(EnrollmentID.init(serverID:)),
            contractVersion: contractVersion,
            signerKind: signer,
            signerDisplayName: signerDisplayName,
            consentedAt: SupabaseDateCodec.timestamp(from: consentedAt),
            signaturePNG: signaturePNG
        )
    }
}

struct ContractConsentSignatureRow: Codable, Sendable {
    let contractConsentID: UUID
    let signaturePNG: String

    enum CodingKeys: String, CodingKey {
        case contractConsentID = "contract_consent_id"
        case signaturePNG = "signature_png"
    }

    var decodedPNG: Data? {
        let data: Data?
        if signaturePNG.hasPrefix("\\x") {
            data = Self.decodeHex(signaturePNG.dropFirst(2))
        } else {
            data = Data(base64Encoded: signaturePNG)
        }

        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard let data, data.prefix(pngHeader.count).elementsEqual(pngHeader) else {
            return nil
        }
        return data
    }

    private static func decodeHex(_ hex: Substring) -> Data? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
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

struct NewsArticleRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let title: String
    let summary: String
    let bodyText: String
    let authorName: String
    let status: String
    let publishedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case title
        case summary
        case bodyText = "body_text"
        case authorName = "author_name"
        case status
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ article: NewsArticle, organizationID: UUID) {
        id = article.id.rawValue
        self.organizationID = organizationID
        title = article.title
        summary = article.summary
        bodyText = article.bodyText
        authorName = article.authorName
        status = article.status.rawValue
        publishedAt = article.publishedAt.map(SupabaseDateCodec.timestampString(from:))
        createdAt = SupabaseDateCodec.timestampString(from: article.createdAt)
        updatedAt = SupabaseDateCodec.timestampString(from: article.updatedAt)
    }

    func domain() throws -> NewsArticle {
        guard let status = NewsArticleStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "新闻状态", value: status)
        }
        return try NewsArticle(
            id: NewsArticleID(serverID: id),
            title: title,
            summary: summary,
            bodyText: bodyText,
            authorName: authorName,
            status: status,
            publishedAt: publishedAt.map { try SupabaseDateCodec.timestamp(from: $0) },
            createdAt: SupabaseDateCodec.timestamp(from: createdAt),
            updatedAt: SupabaseDateCodec.timestamp(from: updatedAt)
        )
    }
}

struct NewsArticleImageRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let articleID: UUID
    let kind: String
    let storagePath: String
    let mimeType: String
    let caption: String?
    let sortOrder: Int
    let placementAfterParagraph: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case articleID = "article_id"
        case kind
        case storagePath = "storage_path"
        case mimeType = "mime_type"
        case caption
        case sortOrder = "sort_order"
        case placementAfterParagraph = "placement_after_paragraph"
    }

    init(_ image: NewsArticleImage, organizationID: UUID) {
        id = image.id.rawValue
        self.organizationID = organizationID
        articleID = image.articleID.rawValue
        kind = image.kind.rawValue
        storagePath = image.storagePath
        mimeType = image.mimeType
        caption = image.caption
        sortOrder = image.sortOrder
        placementAfterParagraph = image.placementAfterParagraph
    }

    func domain() throws -> NewsArticleImage {
        guard let kind = NewsArticleImageKind(rawValue: kind) else {
            throw SupabaseRepositoryError.invalidValue(field: "新闻图片类型", value: kind)
        }
        return NewsArticleImage(
            id: NewsArticleImageID(serverID: id),
            articleID: NewsArticleID(serverID: articleID),
            kind: kind,
            storagePath: storagePath,
            mimeType: mimeType,
            caption: caption,
            sortOrder: sortOrder,
            placementAfterParagraph: placementAfterParagraph
        )
    }
}

struct AdvertisementRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let slotNumber: Int
    let advertiserName: String
    let copyText: String
    let startsOn: String
    let endsOn: String
    let monthlyRateCents: Int
    let status: String
    let thumbnailStoragePath: String?
    let thumbnailMimeType: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let thumbnailByteCount: Int?
    let posterStoragePath: String?
    let posterMimeType: String?
    let posterWidth: Int?
    let posterHeight: Int?
    let posterByteCount: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case slotNumber = "slot_number"
        case advertiserName = "advertiser_name"
        case copyText = "copy_text"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case monthlyRateCents = "monthly_rate_cents"
        case status
        case thumbnailStoragePath = "thumbnail_storage_path"
        case thumbnailMimeType = "thumbnail_mime_type"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
        case thumbnailByteCount = "thumbnail_byte_count"
        case posterStoragePath = "poster_storage_path"
        case posterMimeType = "poster_mime_type"
        case posterWidth = "poster_width"
        case posterHeight = "poster_height"
        case posterByteCount = "poster_byte_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ advertisement: Advertisement, organizationID: UUID) {
        id = advertisement.id.rawValue
        self.organizationID = organizationID
        slotNumber = advertisement.slotNumber
        advertiserName = advertisement.advertiserName
        copyText = advertisement.copyText
        startsOn = SupabaseDateCodec.dayString(from: advertisement.startsOn)
        endsOn = SupabaseDateCodec.dayString(from: advertisement.endsOn)
        monthlyRateCents = advertisement.monthlyRateCents
        status = advertisement.status.rawValue
        thumbnailStoragePath = advertisement.thumbnail?.storagePath
        thumbnailMimeType = advertisement.thumbnail?.mimeType
        thumbnailWidth = advertisement.thumbnail?.pixelWidth
        thumbnailHeight = advertisement.thumbnail?.pixelHeight
        thumbnailByteCount = advertisement.thumbnail?.byteCount
        posterStoragePath = advertisement.poster?.storagePath
        posterMimeType = advertisement.poster?.mimeType
        posterWidth = advertisement.poster?.pixelWidth
        posterHeight = advertisement.poster?.pixelHeight
        posterByteCount = advertisement.poster?.byteCount
        createdAt = SupabaseDateCodec.timestampString(from: advertisement.createdAt)
        updatedAt = SupabaseDateCodec.timestampString(from: advertisement.updatedAt)
    }

    func domain() throws -> Advertisement {
        guard let status = AdvertisementStatus(rawValue: status) else {
            throw SupabaseRepositoryError.invalidValue(field: "广告状态", value: status)
        }
        return try Advertisement(
            id: AdvertisementID(serverID: id),
            slotNumber: slotNumber,
            advertiserName: advertiserName,
            copyText: copyText,
            thumbnail: media(
                storagePath: thumbnailStoragePath,
                mimeType: thumbnailMimeType,
                width: thumbnailWidth,
                height: thumbnailHeight,
                byteCount: thumbnailByteCount
            ),
            poster: media(
                storagePath: posterStoragePath,
                mimeType: posterMimeType,
                width: posterWidth,
                height: posterHeight,
                byteCount: posterByteCount
            ),
            startsOn: SupabaseDateCodec.date(from: startsOn),
            endsOn: SupabaseDateCodec.date(from: endsOn),
            monthlyRateCents: monthlyRateCents,
            status: status,
            createdAt: SupabaseDateCodec.timestamp(from: createdAt),
            updatedAt: SupabaseDateCodec.timestamp(from: updatedAt)
        )
    }

    private func media(
        storagePath: String?,
        mimeType: String?,
        width: Int?,
        height: Int?,
        byteCount: Int?
    ) -> AdvertisementMedia? {
        guard let storagePath,
              let mimeType,
              let width,
              let height,
              let byteCount else {
            return nil
        }
        return AdvertisementMedia(
            storagePath: storagePath,
            mimeType: mimeType,
            pixelWidth: width,
            pixelHeight: height,
            byteCount: byteCount
        )
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

struct BillingInvoiceRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let guardianID: UUID
    let termID: UUID?
    let invoiceNumber: String
    let version: Int
    let schoolYearLabel: String
    let issuedAt: String
    let currency: String
    let amountDueCents: Int
    let notes: String?
    let supersedesInvoiceID: UUID?
    let supersededByInvoiceID: UUID?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case guardianID = "guardian_id"
        case termID = "term_id"
        case invoiceNumber = "invoice_number"
        case version
        case schoolYearLabel = "school_year_label"
        case issuedAt = "issued_at"
        case currency
        case amountDueCents = "amount_due_cents"
        case notes
        case supersedesInvoiceID = "supersedes_invoice_id"
        case supersededByInvoiceID = "superseded_by_invoice_id"
        case createdAt = "created_at"
    }

    func domain() throws -> BillingInvoice {
        guard let currency = BillingCurrency(rawValue: currency) else {
            throw SupabaseRepositoryError.invalidValue(field: "账单币种", value: currency)
        }
        return try BillingInvoice(
            id: BillingInvoiceID(serverID: id),
            guardianID: GuardianID(serverID: guardianID),
            termID: termID.map(TermID.init(serverID:)),
            invoiceNumber: invoiceNumber,
            version: version,
            schoolYearLabel: schoolYearLabel,
            issuedAt: SupabaseDateCodec.timestamp(from: issuedAt),
            currency: currency,
            amountDueCents: amountDueCents,
            notes: notes,
            supersedesInvoiceID: supersedesInvoiceID.map(BillingInvoiceID.init(serverID:)),
            supersededByInvoiceID: supersededByInvoiceID.map(BillingInvoiceID.init(serverID:)),
            createdAt: SupabaseDateCodec.timestamp(from: createdAt)
        )
    }
}

struct BillingInvoiceLineItemRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let invoiceID: UUID
    let studentID: UUID?
    let enrollmentID: UUID?
    let kind: String
    let title: String
    let detail: String?
    let quantity: Int
    let unitAmountCents: Int
    let amountCents: Int
    let includedInAmountDue: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case invoiceID = "invoice_id"
        case studentID = "student_id"
        case enrollmentID = "enrollment_id"
        case kind
        case title
        case detail
        case quantity
        case unitAmountCents = "unit_amount_cents"
        case amountCents = "amount_cents"
        case includedInAmountDue = "included_in_amount_due"
        case sortOrder = "sort_order"
    }

    func domain() throws -> BillingInvoiceLineItem {
        guard let kind = BillingLineItemKind(rawValue: kind) else {
            throw SupabaseRepositoryError.invalidValue(field: "账单项目种类", value: kind)
        }
        return BillingInvoiceLineItem(
            id: BillingInvoiceLineItemID(serverID: id),
            invoiceID: BillingInvoiceID(serverID: invoiceID),
            studentID: studentID.map(StudentID.init(serverID:)),
            enrollmentID: enrollmentID.map(EnrollmentID.init(serverID:)),
            kind: kind,
            title: title,
            detail: detail,
            quantity: quantity,
            unitAmountCents: unitAmountCents,
            amountCents: amountCents,
            includedInAmountDue: includedInAmountDue,
            sortOrder: sortOrder
        )
    }
}

struct BillingPaymentRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let invoiceID: UUID
    let amountCents: Int
    let processingFeeCents: Int
    let method: String
    let receivedAt: String
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case invoiceID = "invoice_id"
        case amountCents = "amount_cents"
        case processingFeeCents = "processing_fee_cents"
        case method
        case receivedAt = "received_at"
        case note
        case createdAt = "created_at"
    }

    func domain() throws -> BillingPayment {
        guard let method = BillingPaymentMethod(rawValue: method) else {
            throw SupabaseRepositoryError.invalidValue(field: "付款方式", value: method)
        }
        return try BillingPayment(
            id: BillingPaymentID(serverID: id),
            invoiceID: BillingInvoiceID(serverID: invoiceID),
            amountCents: amountCents,
            processingFeeCents: processingFeeCents,
            method: method,
            receivedAt: SupabaseDateCodec.timestamp(from: receivedAt),
            note: note,
            createdAt: SupabaseDateCodec.timestamp(from: createdAt)
        )
    }
}

struct BillingArtifactRow: Codable, Sendable {
    let id: UUID
    let organizationID: UUID
    let invoiceID: UUID
    let paymentID: UUID?
    let kind: String
    let storagePath: String
    let mimeType: String
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case invoiceID = "invoice_id"
        case paymentID = "payment_id"
        case kind
        case storagePath = "storage_path"
        case mimeType = "mime_type"
        case generatedAt = "generated_at"
    }

    func domain() throws -> BillingArtifact {
        guard let kind = BillingArtifactKind(rawValue: kind) else {
            throw SupabaseRepositoryError.invalidValue(field: "账单文件种类", value: kind)
        }
        return try BillingArtifact(
            id: BillingArtifactID(serverID: id),
            invoiceID: BillingInvoiceID(serverID: invoiceID),
            paymentID: paymentID.map(BillingPaymentID.init(serverID:)),
            kind: kind,
            storagePath: storagePath,
            mimeType: mimeType,
            generatedAt: SupabaseDateCodec.timestamp(from: generatedAt)
        )
    }
}

struct BillingInvoiceItemPayload: Encodable, Sendable {
    let id: UUID
    let studentID: UUID?
    let enrollmentID: UUID?
    let kind: String
    let title: String
    let detail: String?
    let quantity: Int
    let unitAmountCents: Int
    let amountCents: Int
    let includedInAmountDue: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case studentID = "student_id"
        case enrollmentID = "enrollment_id"
        case kind
        case title
        case detail
        case quantity
        case unitAmountCents = "unit_amount_cents"
        case amountCents = "amount_cents"
        case includedInAmountDue = "included_in_amount_due"
        case sortOrder = "sort_order"
    }

    init(_ item: BillingInvoiceLineItem) {
        id = item.id.rawValue
        studentID = item.studentID?.rawValue
        enrollmentID = item.enrollmentID?.rawValue
        kind = item.kind.rawValue
        title = item.title
        detail = item.detail
        quantity = item.quantity
        unitAmountCents = item.unitAmountCents
        amountCents = item.amountCents
        includedInAmountDue = item.includedInAmountDue
        sortOrder = item.sortOrder
    }
}

struct IssueBillingInvoiceParameters: Encodable, Sendable {
    let invoiceID: UUID
    let guardianID: UUID
    let termID: UUID
    let invoiceNumber: String
    let version: Int
    let schoolYearLabel: String
    let issuedAt: String
    let notes: String
    let supersedesInvoiceID: UUID?
    let artifactID: UUID
    let storagePath: String
    let items: [BillingInvoiceItemPayload]

    enum CodingKeys: String, CodingKey {
        case invoiceID = "target_invoice_id"
        case guardianID = "target_guardian_id"
        case termID = "target_term_id"
        case invoiceNumber = "target_invoice_number"
        case version = "target_version"
        case schoolYearLabel = "target_school_year_label"
        case issuedAt = "target_issued_at"
        case notes = "target_notes"
        case supersedesInvoiceID = "target_supersedes_invoice_id"
        case artifactID = "target_artifact_id"
        case storagePath = "target_storage_path"
        case items = "target_items"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(invoiceID, forKey: .invoiceID)
        try container.encode(guardianID, forKey: .guardianID)
        try container.encode(termID, forKey: .termID)
        try container.encode(invoiceNumber, forKey: .invoiceNumber)
        try container.encode(version, forKey: .version)
        try container.encode(schoolYearLabel, forKey: .schoolYearLabel)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(notes, forKey: .notes)
        if let supersedesInvoiceID {
            try container.encode(supersedesInvoiceID, forKey: .supersedesInvoiceID)
        } else {
            try container.encodeNil(forKey: .supersedesInvoiceID)
        }
        try container.encode(artifactID, forKey: .artifactID)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encode(items, forKey: .items)
    }
}

struct RecordBillingPaymentParameters: Encodable, Sendable {
    let paymentID: UUID
    let invoiceID: UUID
    let amountCents: Int
    let processingFeeCents: Int
    let method: String
    let receivedAt: String
    let note: String
    let artifactID: UUID
    let storagePath: String

    enum CodingKeys: String, CodingKey {
        case paymentID = "target_payment_id"
        case invoiceID = "target_invoice_id"
        case amountCents = "target_amount_cents"
        case processingFeeCents = "target_processing_fee_cents"
        case method = "target_method"
        case receivedAt = "target_received_at"
        case note = "target_note"
        case artifactID = "target_artifact_id"
        case storagePath = "target_storage_path"
    }
}
