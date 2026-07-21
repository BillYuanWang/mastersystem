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

    func latestRemoteChangeSequence() async throws -> Int64? {
        let rows: [SyncRevisionRow] = try await client
            .rpc("current_sync_revision")
            .execute()
            .value
        return rows.first?.changeSequence
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

    func deleteTerm(id: TermID) async throws {
        try await deleteRecord(kind: "term", id: id.rawValue)
    }

    func listTermHolidays(termID: TermID?) async throws -> [TermHoliday] {
        let rows: [TermHolidayRow]
        if let termID {
            rows = try await client
                .from("term_holidays")
                .select()
                .eq("term_id", value: termID.rawValue)
                .order("starts_on")
                .execute()
                .value
        } else {
            rows = try await client
                .from("term_holidays")
                .select()
                .order("starts_on")
                .execute()
                .value
        }
        return try rows.map { try $0.domain() }
    }

    func save(termHoliday: TermHoliday) async throws {
        try await client.from("term_holidays")
            .upsert(TermHolidayRow(termHoliday, organizationID: organizationID)).execute()
    }

    func deleteTermHoliday(id: TermHolidayID) async throws {
        try await deleteRecord(kind: "term_holiday", id: id.rawValue)
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

    func listCourseTypes() async throws -> [CourseType] {
        let rows: [CourseTypeRow] = try await client
            .from("course_types")
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

    func save(courseType: CourseType) async throws {
        try await client
            .from("course_types")
            .upsert(CourseTypeRow(courseType, organizationID: organizationID))
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
        try await deleteRecord(kind: "course_category", id: id.rawValue)
    }

    func deleteCourseType(id: CourseTypeID) async throws {
        try await deleteRecord(kind: "course_type", id: id.rawValue)
    }

    func deleteAgeGroup(id: AgeGroupID) async throws {
        try await deleteRecord(kind: "age_group", id: id.rawValue)
    }

    func deleteRoom(id: RoomID) async throws {
        try await deleteRecord(kind: "room", id: id.rawValue)
    }

    func deleteInstructor(id: InstructorID) async throws {
        try await deleteRecord(kind: "instructor", id: id.rawValue)
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

    func deleteCourse(id: CourseID) async throws {
        try await deleteRecord(kind: "course", id: id.rawValue)
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

    func deleteSession(id: ClassSessionID) async throws {
        try await client.from("class_sessions").delete().eq("id", value: id.rawValue).execute()
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

        let linkStatuses: [GuardianLinkStatusRow]
        do {
            linkStatuses = try await client
                .rpc("admin_list_guardian_link_statuses")
                .execute()
                .value
        } catch {
            // Keeps an older backend readable while a new app/backend release rolls out.
            linkStatuses = []
        }
        let linkStatusByGuardian = Dictionary(
            uniqueKeysWithValues: linkStatuses.map { ($0.guardianID, $0) }
        )

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

        return try guardianRows.compactMap { row in
            if studentID != nil, !allowedGuardianIDs.contains(row.id) {
                return nil
            }
            let status = linkStatusByGuardian[row.id]
            let activeCodeExpiresAt: Date?
            if let value = status?.activeCodeExpiresAt {
                activeCodeExpiresAt = try SupabaseDateCodec.timestamp(from: value)
            } else {
                activeCodeExpiresAt = nil
            }
            return Guardian(
                id: GuardianID(serverID: row.id),
                displayName: row.displayName,
                email: row.email,
                phone: row.phone,
                address: row.address,
                profileUserID: status?.linkedUserID ?? row.profileUserID,
                studentIDs: studentIDsByGuardian[row.id] ?? [],
                activeLinkCodeHint: status?.activeCodeHint,
                activeLinkCodeExpiresAt: activeCodeExpiresAt
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

        for studentID in guardian.studentIDs {
            try await link(studentID: studentID, to: guardian.id)
        }
    }

    func create(student: Student, for guardianID: GuardianID) async throws -> Student {
        let created: StudentRow = try await client
            .rpc(
                "admin_create_student_for_guardian",
                params: CreateStudentForGuardianParameters(
                    guardianID: guardianID.rawValue,
                    displayName: student.displayName,
                    legalName: student.legalName,
                    kind: student.kind.rawValue,
                    birthDate: student.birthDate.map(SupabaseDateCodec.dayString(from:))
                )
            )
            .execute()
            .value
        return try created.domain()
    }

    func link(studentID: StudentID, to guardianID: GuardianID) async throws {
        let _: GuardianStudentRow = try await client
            .rpc(
                "admin_link_student_to_guardian",
                params: LinkStudentToGuardianParameters(
                    guardianID: guardianID.rawValue,
                    studentID: studentID.rawValue
                )
            )
            .execute()
            .value
    }

    func issueGuardianLinkCode(guardianID: GuardianID) async throws -> GuardianLinkCode {
        let issued: GuardianLinkCodeRow = try await client
            .rpc(
                "admin_issue_guardian_link_code",
                params: IssueGuardianLinkCodeParameters(
                    guardianID: guardianID.rawValue,
                    validityDays: 30
                )
            )
            .execute()
            .value
        return try issued.domain()
    }

    func deleteStudent(id: StudentID) async throws {
        try await deleteRecord(kind: "student", id: id.rawValue)
    }

    func deleteGuardian(id: GuardianID) async throws {
        try await client
            .rpc(
                "admin_delete_guardian_household",
                params: AdminDeleteGuardianHouseholdParameters(
                    guardianID: id.rawValue
                )
            )
            .execute()
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

    func deleteAttendance(id: AttendanceID) async throws {
        try await client.from("attendance").delete().eq("id", value: id.rawValue).execute()
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

    func deleteLeaveRequest(id: LeaveRequestID) async throws {
        try await client.from("leave_requests").delete().eq("id", value: id.rawValue).execute()
    }

    func listContractDocuments(termID: TermID?) async throws -> [ContractDocument] {
        let rows: [ContractDocumentRow]
        if let termID {
            rows = try await client
                .from("contract_documents")
                .select()
                .eq("term_id", value: termID.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            rows = try await client
                .from("contract_documents")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return try rows.map { try $0.domain() }
    }

    func save(
        contractDocument: ContractDocument,
        fileData: Data?
    ) async throws -> ContractDocument {
        var saved = contractDocument
        if saved.status == .published, saved.publishedAt == nil {
            saved.publishedAt = Date()
        } else if saved.status == .draft {
            saved.publishedAt = nil
        }

        saved.title = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.bodyText = saved.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saved.bodyText.isEmpty else {
            throw SupabaseRepositoryError.server("请填写协议正文。")
        }

        if let fileData {
            if saved.storagePath.isEmpty {
                saved.storagePath = [
                    organizationID.uuidString.lowercased(),
                    saved.termID.rawValue.uuidString.lowercased(),
                    saved.id.rawValue.uuidString.lowercased() + ".pdf"
                ].joined(separator: "/")
            }
            try await client.storage
                .from("contracts")
                .upload(
                    saved.storagePath,
                    data: fileData,
                    options: FileOptions(contentType: "application/pdf", upsert: true)
                )
        }

        let row = ContractDocumentRow(saved, organizationID: organizationID)
        let stored: ContractDocumentRow = try await client
            .from("contract_documents")
            .upsert(row)
            .select()
            .single()
            .execute()
            .value
        return try stored.domain()
    }

    func publishContractRevision(
        termID: TermID,
        title: String,
        bodyText: String
    ) async throws -> ContractDocument {
        let stored: ContractDocumentRow = try await client
            .rpc(
                "admin_publish_contract_revision",
                params: PublishContractRevisionParameters(
                    termID: termID.rawValue,
                    title: title,
                    bodyText: bodyText
                )
            )
            .execute()
            .value
        return try stored.domain()
    }

    func deleteContractDocument(id: ContractDocumentID, storagePath: String) async throws {
        try await deleteRecord(kind: "contract_document", id: id.rawValue)
        guard !storagePath.isEmpty else { return }
        _ = try? await client.storage.from("contracts").remove(paths: [storagePath])
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

        let signatureRows: [ContractConsentSignatureRow]
        if consentRows.isEmpty {
            signatureRows = []
        } else {
            signatureRows = try await client
                .from("contract_consent_signatures")
                .select("contract_consent_id, signature_png")
                .in("contract_consent_id", values: consentRows.map(\.id))
                .execute()
                .value
        }
        let signatures = Dictionary(
            uniqueKeysWithValues: signatureRows.compactMap { row in
                row.decodedPNG.map { (row.contractConsentID, $0) }
            }
        )

        return try consentRows.map { row in
            guard let version = versions[row.contractDocumentID] else {
                throw SupabaseRepositoryError.missingContractDocument(row.contractDocumentID)
            }
            return try row.domain(
                contractVersion: version,
                signaturePNG: signatures[row.id]
            )
        }
    }

    func save(contractConsent: ContractConsent) async throws {
        throw SupabaseRepositoryError.server("合同同意必须通过已发布合同的受控签署流程记录。")
    }

    func listNewsArticles() async throws -> [NewsArticle] {
        let rows: [NewsArticleRow] = try await client
            .from("news_articles")
            .select()
            .order("published_at", ascending: false, nullsFirst: false)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return try rows.map { try $0.domain() }
    }

    func listNewsArticleImages(articleID: NewsArticleID?) async throws -> [NewsArticleImage] {
        let rows: [NewsArticleImageRow]
        if let articleID {
            rows = try await client
                .from("news_article_images")
                .select()
                .eq("article_id", value: articleID.rawValue)
                .order("sort_order")
                .execute()
                .value
        } else {
            rows = try await client
                .from("news_article_images")
                .select()
                .order("sort_order")
                .execute()
                .value
        }
        return try rows.map { try $0.domain() }
    }

    func save(newsArticle: NewsArticle) async throws -> NewsArticle {
        var saved = newsArticle
        saved.title = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.summary = saved.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.bodyText = saved.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.authorName = saved.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saved.title.isEmpty else {
            throw SupabaseRepositoryError.server("请输入新闻标题。")
        }
        guard !saved.bodyText.isEmpty else {
            throw SupabaseRepositoryError.server("请输入新闻正文。")
        }
        guard !saved.authorName.isEmpty else {
            throw SupabaseRepositoryError.server("请输入作者。")
        }

        let now = Date()
        saved.updatedAt = now
        if saved.status == .published, saved.publishedAt == nil {
            saved.publishedAt = now
        } else if saved.status == .draft {
            saved.publishedAt = nil
        }

        let stored: NewsArticleRow = try await client
            .from("news_articles")
            .upsert(NewsArticleRow(saved, organizationID: organizationID))
            .select()
            .single()
            .execute()
            .value
        return try stored.domain()
    }

    func save(
        newsArticleImage: NewsArticleImage,
        fileData: Data?
    ) async throws -> NewsArticleImage {
        var saved = newsArticleImage
        let caption = saved.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        saved.caption = caption.isEmpty ? nil : caption

        if saved.storagePath.isEmpty {
            guard fileData != nil else {
                throw SupabaseRepositoryError.server("请选择新闻图片。")
            }
            saved.storagePath = [
                organizationID.uuidString.lowercased(),
                saved.articleID.rawValue.uuidString.lowercased(),
                saved.id.rawValue.uuidString.lowercased() + "." + newsFileExtension(for: saved.mimeType)
            ].joined(separator: "/")
        }

        if let fileData {
            try await client.storage
                .from("news-media")
                .upload(
                    saved.storagePath,
                    data: fileData,
                    options: FileOptions(contentType: saved.mimeType, upsert: true)
                )
        }

        let stored: NewsArticleImageRow = try await client
            .from("news_article_images")
            .upsert(NewsArticleImageRow(saved, organizationID: organizationID))
            .select()
            .single()
            .execute()
            .value
        return try stored.domain()
    }

    func deleteNewsArticle(id: NewsArticleID) async throws {
        let rows: [NewsArticleImageRow] = try await client
            .from("news_article_images")
            .select()
            .eq("article_id", value: id.rawValue)
            .execute()
            .value
        try await client.from("news_articles").delete().eq("id", value: id.rawValue).execute()
        let paths = rows.map(\.storagePath)
        if !paths.isEmpty {
            _ = try? await client.storage.from("news-media").remove(paths: paths)
        }
    }

    func deleteNewsArticleImage(id: NewsArticleImageID, storagePath: String) async throws {
        try await client.from("news_article_images").delete().eq("id", value: id.rawValue).execute()
        guard !storagePath.isEmpty else { return }
        _ = try? await client.storage.from("news-media").remove(paths: [storagePath])
    }

    func newsMediaData(storagePath: String) async throws -> Data {
        try await client.storage.from("news-media").download(path: storagePath)
    }

    func listAdvertisements() async throws -> [Advertisement] {
        let rows: [AdvertisementRow] = try await client
            .from("advertisements")
            .select()
            .order("slot_number")
            .order("starts_on", ascending: false)
            .execute()
            .value
        return try rows.map { try $0.domain() }
    }

    func save(
        advertisement: Advertisement,
        thumbnailData: Data?,
        posterData: Data?
    ) async throws -> Advertisement {
        let previousRows: [AdvertisementRow] = try await client
            .from("advertisements")
            .select()
            .eq("id", value: advertisement.id.rawValue)
            .limit(1)
            .execute()
            .value
        let previous = try previousRows.first?.domain()

        var saved = advertisement
        saved.advertiserName = saved.advertiserName.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.copyText = saved.copyText.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.createdAt = previous?.createdAt ?? saved.createdAt
        saved.updatedAt = Date()
        saved.thumbnail = try await uploadAdvertisementMedia(
            advertisementID: saved.id,
            kind: "thumbnail",
            media: saved.thumbnail,
            fileData: thumbnailData
        )
        saved.poster = try await uploadAdvertisementMedia(
            advertisementID: saved.id,
            kind: "poster",
            media: saved.poster,
            fileData: posterData
        )
        try validate(advertisement: saved)

        let stored: AdvertisementRow = try await client
            .from("advertisements")
            .upsert(AdvertisementRow(saved, organizationID: organizationID))
            .select()
            .single()
            .execute()
            .value

        let result = try stored.domain()
        let oldPaths = [previous?.thumbnail?.storagePath, previous?.poster?.storagePath].compactMap { $0 }
        let newPaths = Set([result.thumbnail?.storagePath, result.poster?.storagePath].compactMap { $0 })
        let retiredPaths = oldPaths.filter { !newPaths.contains($0) }
        if !retiredPaths.isEmpty {
            _ = try? await client.storage.from("advertisement-media").remove(paths: retiredPaths)
        }
        return result
    }

    func deleteAdvertisement(id: AdvertisementID) async throws {
        let rows: [AdvertisementRow] = try await client
            .from("advertisements")
            .select()
            .eq("id", value: id.rawValue)
            .limit(1)
            .execute()
            .value
        try await client.from("advertisements").delete().eq("id", value: id.rawValue).execute()
        guard let row = rows.first else { return }
        let paths = [row.thumbnailStoragePath, row.posterStoragePath].compactMap { $0 }
        if !paths.isEmpty {
            _ = try? await client.storage.from("advertisement-media").remove(paths: paths)
        }
    }

    func advertisementMediaData(storagePath: String) async throws -> Data {
        try await client.storage.from("advertisement-media").download(path: storagePath)
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

    private func deleteRecord(kind: String, id: UUID) async throws {
        try await client
            .rpc(
                "admin_delete_record",
                params: AdminDeleteRecordParameters(
                    kind: kind,
                    id: id
                )
            )
            .execute()
    }

    private func currentUserID() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw SupabaseRepositoryError.missingSession
        }
    }

    private func uploadAdvertisementMedia(
        advertisementID: AdvertisementID,
        kind: String,
        media: AdvertisementMedia?,
        fileData: Data?
    ) async throws -> AdvertisementMedia? {
        guard let fileData else { return media }
        guard var media else {
            throw SupabaseRepositoryError.server("请选择广告图片。")
        }
        guard supportedAdvertisementMimeTypes.contains(media.mimeType.lowercased()) else {
            throw SupabaseRepositoryError.server("广告图片仅支持 JPEG、PNG 和 HEIC。")
        }
        media.byteCount = fileData.count
        media.storagePath = [
            organizationID.uuidString.lowercased(),
            advertisementID.rawValue.uuidString.lowercased(),
            kind + "." + advertisementFileExtension(for: media.mimeType)
        ].joined(separator: "/")
        try await client.storage
            .from("advertisement-media")
            .upload(
                media.storagePath,
                data: fileData,
                options: FileOptions(contentType: media.mimeType, upsert: true)
            )
        return media
    }

    private func validate(advertisement: Advertisement) throws {
        guard AdvertisementRules.slotRange.contains(advertisement.slotNumber) else {
            throw SupabaseRepositoryError.server("广告位必须在 1 到 5 之间。")
        }
        guard !advertisement.advertiserName.isEmpty,
              advertisement.advertiserName.count <= AdvertisementRules.maximumAdvertiserNameCount else {
            throw SupabaseRepositoryError.server("广告名称需要填写，且不能超过 40 个字符。")
        }
        guard !advertisement.copyText.isEmpty,
              advertisement.copyText.count <= AdvertisementRules.maximumCopyCount else {
            throw SupabaseRepositoryError.server("广告文字需要填写，且不能超过 120 个字符。")
        }
        guard advertisement.startsOn <= advertisement.endsOn else {
            throw SupabaseRepositoryError.server("广告结束日期不能早于起始日期。")
        }
        guard advertisement.monthlyRateCents == AdvertisementRules.monthlyRateCents else {
            throw SupabaseRepositoryError.server("广告月费必须为 $99。")
        }
        if let thumbnail = advertisement.thumbnail {
            guard supportedAdvertisementMimeTypes.contains(thumbnail.mimeType.lowercased()),
                  AdvertisementRules.isValidThumbnail(
                    width: thumbnail.pixelWidth,
                    height: thumbnail.pixelHeight
                  ),
                  thumbnail.byteCount <= AdvertisementRules.maximumFileByteCount else {
                throw SupabaseRepositoryError.server("缩略图必须为 1:1，至少 600×600，且不超过 8 MB。")
            }
        }
        if let poster = advertisement.poster {
            guard supportedAdvertisementMimeTypes.contains(poster.mimeType.lowercased()),
                  AdvertisementRules.isValidPoster(
                    width: poster.pixelWidth,
                    height: poster.pixelHeight
                  ),
                  poster.byteCount <= AdvertisementRules.maximumFileByteCount else {
                throw SupabaseRepositoryError.server("海报必须为 4:5，至少 900×1125，且不超过 8 MB。")
            }
        }
        if advertisement.status == .published {
            guard let thumbnail = advertisement.thumbnail,
                  let poster = advertisement.poster,
                  !thumbnail.storagePath.isEmpty,
                  !poster.storagePath.isEmpty else {
                throw SupabaseRepositoryError.server("发布广告前需要方形缩略图和 4:5 竖版海报。")
            }
        }
    }

    private var supportedAdvertisementMimeTypes: Set<String> {
        ["image/jpeg", "image/png", "image/heic", "image/heif"]
    }

    private func advertisementFileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png": "png"
        case "image/heic", "image/heif": "heic"
        default: "jpg"
        }
    }

    private func newsFileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png": "png"
        case "image/heic", "image/heif": "heic"
        case "image/webp": "webp"
        default: "jpg"
        }
    }
}

private struct PublishContractRevisionParameters: Encodable {
    let termID: UUID
    let title: String
    let bodyText: String

    enum CodingKeys: String, CodingKey {
        case termID = "target_term_id"
        case title = "document_title"
        case bodyText = "document_body_text"
    }
}
