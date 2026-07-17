import Foundation
import MasterDanceCore
import Supabase

actor SupabaseMasterDanceRepository: MasterDanceRepository {
    private let client: SupabaseClient
    private let organizationID: UUID

    init(client: SupabaseClient, organizationID: UUID) {
        self.client = client
        self.organizationID = organizationID
    }

    func listTerms() async throws -> [Term] {
        let rows: [TermRow] = try await client
            .from("terms")
            .select()
            .order("starts_on", ascending: false)
            .execute()
            .value
        return try rows.map { try $0.domain() }
    }

    func save(term: Term) async throws {
        try await client.from("terms").upsert(TermRow(term, organizationID: organizationID)).execute()
    }

    func listCourseCategories() async throws -> [CourseCategory] {
        let rows: [CourseCategoryRow] = try await client
            .from("course_categories")
            .select()
            .order("name")
            .execute()
            .value
        return rows.map { $0.domain() }
    }

    func listAgeGroups() async throws -> [AgeGroup] {
        let rows: [AgeGroupRow] = try await client
            .from("age_groups")
            .select()
            .order("name")
            .execute()
            .value
        return rows.map { $0.domain() }
    }

    func listRooms() async throws -> [Room] {
        let rows: [RoomRow] = try await client
            .from("rooms")
            .select()
            .order("name")
            .execute()
            .value
        return rows.map { $0.domain() }
    }

    func listInstructors() async throws -> [Instructor] {
        let rows: [InstructorRow] = try await client
            .from("instructors")
            .select()
            .order("display_name")
            .execute()
            .value
        return rows.map { $0.domain() }
    }

    func save(courseCategory: CourseCategory) async throws {
        try await client
            .from("course_categories")
            .upsert(CourseCategoryRow(courseCategory, organizationID: organizationID))
            .execute()
    }

    func save(ageGroup: AgeGroup) async throws {
        try await client
            .from("age_groups")
            .upsert(AgeGroupRow(ageGroup, organizationID: organizationID))
            .execute()
    }

    func save(room: Room) async throws {
        try await client
            .from("rooms")
            .upsert(RoomRow(room, organizationID: organizationID))
            .execute()
    }

    func save(instructor: Instructor) async throws {
        try await client
            .from("instructors")
            .upsert(InstructorRow(instructor, organizationID: organizationID))
            .execute()
    }

    func deleteCourseCategory(id: CourseCategoryID) async throws {
        try await client.from("course_categories").delete().eq("id", value: id.rawValue).execute()
    }

    func deleteAgeGroup(id: AgeGroupID) async throws {
        try await client.from("age_groups").delete().eq("id", value: id.rawValue).execute()
    }

    func deleteRoom(id: RoomID) async throws {
        try await client.from("rooms").delete().eq("id", value: id.rawValue).execute()
    }

    func deleteInstructor(id: InstructorID) async throws {
        try await client.from("instructors").delete().eq("id", value: id.rawValue).execute()
    }

    func listCourses(termID: TermID?) async throws -> [Course] {
        let rows: [CourseRow]
        if let termID {
            rows = try await client
                .from("courses")
                .select()
                .eq("term_id", value: termID.rawValue)
                .order("name")
                .execute()
                .value
        } else {
            rows = try await client
                .from("courses")
                .select()
                .order("name")
                .execute()
                .value
        }
        return try rows.map { try $0.domain() }
    }

    func save(course: Course) async throws {
        try await client.from("courses").upsert(CourseRow(course, organizationID: organizationID)).execute()
    }

    func listSessions(courseID: CourseID?) async throws -> [ClassSession] {
        let rows: [ClassSessionRow]
        if let courseID {
            rows = try await client
                .from("class_sessions")
                .select()
                .eq("course_id", value: courseID.rawValue)
                .order("starts_at")
                .execute()
                .value
        } else {
            rows = try await client
                .from("class_sessions")
                .select()
                .order("starts_at")
                .execute()
                .value
        }
        return try rows.map { try $0.domain() }
    }

    func save(session: ClassSession) async throws {
        try await client
            .from("class_sessions")
            .upsert(ClassSessionRow(session, organizationID: organizationID))
            .execute()
    }

    func listStudents() async throws -> [Student] {
        let rows: [StudentRow] = try await client
            .from("students")
            .select()
            .order("display_name")
            .execute()
            .value
        return try rows.map { try $0.domain() }
    }

    func listGuardians(studentID: StudentID?) async throws -> [Guardian] {
        let guardianRows: [GuardianRow] = try await client
            .from("guardians")
            .select()
            .order("display_name")
            .execute()
            .value

        let links: [GuardianStudentRow]
        if let studentID {
            links = try await client
                .from("guardian_students")
                .select()
                .eq("student_id", value: studentID.rawValue)
                .execute()
                .value
        } else {
            links = try await client
                .from("guardian_students")
                .select()
                .execute()
                .value
        }

        let studentIDsByGuardian = Dictionary(grouping: links, by: \.guardianID)
            .mapValues { Set($0.map { StudentID(serverID: $0.studentID) }) }
        let allowedGuardianIDs = Set(links.map(\.guardianID))

        return guardianRows.compactMap { row in
            if studentID != nil, !allowedGuardianIDs.contains(row.id) {
                return nil
            }
            return Guardian(
                id: GuardianID(serverID: row.id),
                displayName: row.displayName,
                email: row.email,
                phone: row.phone,
                studentIDs: studentIDsByGuardian[row.id] ?? []
            )
        }
    }

    func save(student: Student) async throws {
        try await client.from("students").upsert(StudentRow(student, organizationID: organizationID)).execute()
    }

    func save(guardian: Guardian) async throws {
        try await client
            .from("guardians")
            .upsert(GuardianRow(guardian, organizationID: organizationID))
            .execute()

        try await client
            .from("guardian_students")
            .delete()
            .eq("guardian_id", value: guardian.id.rawValue)
            .execute()

        let links = guardian.studentIDs.map {
            GuardianStudentRow(
                organizationID: organizationID,
                guardianID: guardian.id.rawValue,
                studentID: $0.rawValue,
                isPrimary: false
            )
        }
        if !links.isEmpty {
            try await client.from("guardian_students").insert(links).execute()
        }
    }

    func listEnrollments(
        termID: TermID?,
        courseID: CourseID?,
        studentID: StudentID?
    ) async throws -> [Enrollment] {
        let rows: [EnrollmentRow]
        switch (termID, courseID, studentID) {
        case let (termID?, _, _):
            rows = try await client.from("enrollments").select()
                .eq("term_id", value: termID.rawValue).execute().value
        case let (_, courseID?, _):
            rows = try await client.from("enrollments").select()
                .eq("course_id", value: courseID.rawValue).execute().value
        case let (_, _, studentID?):
            rows = try await client.from("enrollments").select()
                .eq("student_id", value: studentID.rawValue).execute().value
        default:
            rows = try await client.from("enrollments").select().execute().value
        }

        let filtered = rows.filter { row in
            (termID == nil || row.termID == termID?.rawValue)
                && (courseID == nil || row.courseID == courseID?.rawValue)
                && (studentID == nil || row.studentID == studentID?.rawValue)
        }
        return try filtered.map { try $0.domain() }
    }

    func save(enrollment: Enrollment) async throws {
        try await client
            .from("enrollments")
            .upsert(EnrollmentRow(enrollment, organizationID: organizationID))
            .execute()
    }

    func deleteEnrollment(id: EnrollmentID) async throws {
        try await client.from("enrollments").delete().eq("id", value: id.rawValue).execute()
    }

    func listAttendance(sessionID: ClassSessionID?, studentID: StudentID?) async throws -> [Attendance] {
        let rows: [AttendanceRecordRow]
        if let sessionID {
            rows = try await client.from("attendance").select()
                .eq("session_id", value: sessionID.rawValue).execute().value
        } else if let studentID {
            rows = try await client.from("attendance").select()
                .eq("student_id", value: studentID.rawValue).execute().value
        } else {
            rows = try await client.from("attendance").select().execute().value
        }
        return try rows.map { try $0.domain() }
    }

    func save(attendance: Attendance) async throws {
        let currentUserID = try await currentUserID()
        try await client.from("attendance").upsert(
            AttendanceRecordRow(
                attendance,
                organizationID: organizationID,
                recordedBy: currentUserID
            )
        ).execute()
    }

    func listLeaveRequests(
        sessionID: ClassSessionID?,
        studentID: StudentID?
    ) async throws -> [LeaveRequest] {
        let rows: [LeaveRequestRow]
        if let sessionID {
            rows = try await client.from("leave_requests").select()
                .eq("session_id", value: sessionID.rawValue).execute().value
        } else if let studentID {
            rows = try await client.from("leave_requests").select()
                .eq("student_id", value: studentID.rawValue).execute().value
        } else {
            rows = try await client.from("leave_requests").select()
                .order("submitted_at", ascending: false).execute().value
        }
        return try rows.map { try $0.domain() }
    }

    func save(leaveRequest: LeaveRequest) async throws {
        let currentUserID = try await currentUserID()
        let resolvedBy = leaveRequest.resolvedAt == nil ? nil : currentUserID
        try await client.from("leave_requests").upsert(
            LeaveRequestRow(
                leaveRequest,
                organizationID: organizationID,
                submittedBy: currentUserID,
                resolvedBy: resolvedBy
            )
        ).execute()
    }

    func listContractConsents(
        termID: TermID,
        enrollmentID: EnrollmentID?
    ) async throws -> [ContractConsent] {
        let consentRows: [ContractConsentRow]
        if let enrollmentID {
            consentRows = try await client.from("contract_consents").select()
                .eq("term_id", value: termID.rawValue)
                .eq("enrollment_id", value: enrollmentID.rawValue)
                .execute().value
        } else {
            consentRows = try await client.from("contract_consents").select()
                .eq("term_id", value: termID.rawValue)
                .execute().value
        }

        let documentRows: [ContractDocumentSummaryRow] = try await client
            .from("contract_documents")
            .select("id, version")
            .eq("term_id", value: termID.rawValue)
            .execute()
            .value
        let versions = Dictionary(uniqueKeysWithValues: documentRows.map { ($0.id, $0.version) })

        return try consentRows.map { row in
            guard let version = versions[row.contractDocumentID] else {
                throw SupabaseRepositoryError.missingContractDocument(row.contractDocumentID)
            }
            return try row.domain(contractVersion: version)
        }
    }

    func save(contractConsent: ContractConsent) async throws {
        throw SupabaseRepositoryError.server("合同同意必须通过已发布合同的受控签署流程记录。")
    }

    func listNotifications(recipientReference: String?) async throws -> [NotificationRecord] {
        let rows: [NotificationRow]
        if let recipientReference, let recipientID = UUID(uuidString: recipientReference) {
            rows = try await client.from("notifications").select()
                .eq("recipient_user_id", value: recipientID)
                .order("created_at", ascending: false)
                .execute().value
        } else {
            rows = try await client.from("notifications").select()
                .order("created_at", ascending: false)
                .execute().value
        }
        return try rows.map { try $0.domain() }
    }

    func save(notification: NotificationRecord) async throws {
        try await client.from("notifications").upsert(
            try NotificationRow(notification, organizationID: organizationID)
        ).execute()
    }

    private func currentUserID() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw SupabaseRepositoryError.missingSession
        }
    }
}
