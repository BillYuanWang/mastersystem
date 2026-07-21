import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Preview repository")
struct PreviewMasterDanceStoreTests {
    @Test("Trial attendance remains separate from enrollment and can be removed")
    func attendanceDoesNotImplyEnrollment() async throws {
        let guardian = Guardian(displayName: "Trial Family")
        let store = PreviewMasterDanceStore(
            data: PreviewData(guardians: [guardian])
        )
        let student = Student(guardianID: guardian.id, displayName: "Trial Student", kind: .child)
        let attendance = Attendance(
            sessionID: ClassSessionID(),
            studentID: student.id,
            enrollmentID: nil,
            status: .trial,
            recordedAt: Date(timeIntervalSince1970: 1_000)
        )

        try await store.save(student: student)
        try await store.save(attendance: attendance)

        let enrollments = try await store.listEnrollments(
            termID: nil,
            courseID: nil,
            studentID: student.id
        )
        let attendanceRecords = try await store.listAttendance(
            sessionID: nil,
            studentID: student.id
        )
        #expect(enrollments.isEmpty)
        #expect(attendanceRecords == [attendance])

        try await store.deleteAttendance(id: attendance.id)
        let remaining = try await store.listAttendance(sessionID: nil, studentID: student.id)
        #expect(remaining.isEmpty)
    }

    @Test("Attendance statuses distinguish regular and guest visits")
    func attendanceStatusSemantics() {
        #expect(Set(AttendanceStatus.allCases) == [.present, .excused, .absent, .makeup, .trial])
        #expect(AttendanceStatus.trial.isGuestAttendance)
        #expect(AttendanceStatus.makeup.isGuestAttendance)
        #expect(!AttendanceStatus.present.isGuestAttendance)
        #expect(!AttendanceStatus.excused.isGuestAttendance)
        #expect(!AttendanceStatus.absent.isGuestAttendance)
        #expect(AttendanceStatus.present.recordsPhysicalAttendance)
        #expect(AttendanceStatus.trial.recordsPhysicalAttendance)
        #expect(AttendanceStatus.makeup.recordsPhysicalAttendance)
        #expect(!AttendanceStatus.absent.recordsPhysicalAttendance)
        #expect(!AttendanceStatus.excused.recordsPhysicalAttendance)
    }

    @Test("Enrollment queries and removal use stable identities")
    func enrollmentFilteringAndRemoval() async throws {
        let term = Term(
            name: "Term",
            startsOn: .distantPast,
            endsOn: .distantFuture,
            status: .open
        )
        let category = CourseCategory(name: "Custom Dance Style")
        let ageGroup = AgeGroup(name: "Custom Age Band")
        let room = Room(name: "Custom Room")
        let instructor = Instructor(displayName: "Custom Instructor")
        let groupType = CourseType(name: "Large Group", isPrivate: false)
        let privateType = CourseType(name: "Private", isPrivate: true)
        let courseA = Course(
            termID: term.id,
            name: "Course A",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            courseTypeID: groupType.id,
            format: .group
        )
        let courseB = Course(
            termID: term.id,
            name: "Course B",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            courseTypeID: privateType.id,
            format: .privateLesson
        )
        let guardian = Guardian(displayName: "Adult Family")
        let student = Student(guardianID: guardian.id, displayName: "Student", kind: .adult)
        let first = Enrollment(
            termID: term.id,
            courseID: courseA.id,
            studentID: student.id,
            enrolledAt: .distantPast
        )
        let second = Enrollment(
            termID: term.id,
            courseID: courseB.id,
            studentID: student.id,
            enrolledAt: .distantPast
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(enrollments: [first, second])
        )

        let firstCourseEnrollments = try await store.listEnrollments(
            termID: term.id,
            courseID: courseA.id,
            studentID: student.id
        )
        #expect(firstCourseEnrollments == [first])

        try await store.deleteEnrollment(id: first.id)

        let remaining = try await store.listEnrollments(
            termID: term.id,
            courseID: nil,
            studentID: student.id
        )
        #expect(remaining == [second])
    }

    @Test("Saving the same identity updates instead of duplicating")
    func saveUpserts() async throws {
        let term = Term(
            name: "Draft",
            startsOn: .distantPast,
            endsOn: .distantFuture,
            status: .draft
        )
        let store = PreviewMasterDanceStore(data: PreviewData(terms: [term]))
        var updated = term
        updated.name = "Published"
        updated.status = .open

        try await store.save(term: updated)

        let terms = try await store.listTerms()
        #expect(terms == [updated])
    }

    @Test("Guardian lookup supports multiple children")
    func guardianRelationships() async throws {
        let guardian = Guardian(displayName: "Guardian")
        let firstChild = Student(guardianID: guardian.id, displayName: "First", kind: .child)
        let secondChild = Student(guardianID: guardian.id, displayName: "Second", kind: .child)
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [firstChild, secondChild], guardians: [guardian])
        )

        let firstGuardians = try await store.listGuardians(studentID: firstChild.id)
        let secondGuardians = try await store.listGuardians(studentID: secondChild.id)
        #expect(firstGuardians.map(\.id) == [guardian.id])
        #expect(secondGuardians.map(\.id) == [guardian.id])
        #expect(firstGuardians.first?.studentIDs == [firstChild.id, secondChild.id])
    }

    @Test("Deleting an unclaimed family removes empty learner profiles")
    func deletesUnclaimedFamilyWithEmptyLearners() async throws {
        let guardian = Guardian(displayName: "Temporary Family")
        let firstChild = Student(guardianID: guardian.id, displayName: "First", kind: .child)
        let secondChild = Student(guardianID: guardian.id, displayName: "Second", kind: .child)
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [firstChild, secondChild], guardians: [guardian])
        )

        try await store.deleteGuardian(id: guardian.id)

        #expect(try await store.listGuardians(studentID: nil).isEmpty)
        #expect(try await store.listStudents().isEmpty)
    }

    @Test("A family with enrollment history cannot be deleted")
    func protectsFamilyWithEnrollment() async throws {
        let guardian = Guardian(displayName: "Active Family")
        let student = Student(guardianID: guardian.id, displayName: "Student", kind: .child)
        let enrollment = Enrollment(
            termID: TermID(),
            courseID: CourseID(),
            studentID: student.id,
            enrolledAt: Date()
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(
                students: [student],
                guardians: [guardian],
                enrollments: [enrollment]
            )
        )

        await #expect(throws: PreviewRepositoryError.recordInUse("这个家庭仍有学员报名，不能删除；请先撤销报名。")) {
            try await store.deleteGuardian(id: guardian.id)
        }

        #expect(try await store.listGuardians(studentID: nil).map(\.id) == [guardian.id])
        #expect(try await store.listStudents() == [student])
    }

    @Test("A family owns child and adult learner profiles")
    func familyCreatesMultipleLearners() async throws {
        let guardian = Guardian(displayName: "Family")
        let child = Student(guardianID: guardian.id, displayName: "Child", kind: .child)
        let adult = Student(guardianID: guardian.id, displayName: "Adult Self", kind: .adult)
        let store = PreviewMasterDanceStore(
            data: PreviewData(guardians: [guardian])
        )

        _ = try await store.create(student: child, for: guardian.id)
        _ = try await store.create(student: adult, for: guardian.id)

        let savedGuardian = try #require(
            try await store.listGuardians(studentID: nil).first
        )
        #expect(savedGuardian.studentIDs == [child.id, adult.id])
    }

    @Test("Optional family address and learner birthday persist")
    func familyProfileDetailsPersist() async throws {
        let birthDate = Date(timeIntervalSince1970: 1_087_862_400)
        let guardian = Guardian(
            displayName: "Family",
            address: "123 Main Street, Irvine, CA 92618"
        )
        let child = Student(
            guardianID: guardian.id,
            displayName: "Child",
            birthDate: birthDate,
            kind: .child
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [child], guardians: [guardian])
        )

        let savedGuardian = try #require(
            try await store.listGuardians(studentID: nil).first
        )
        let savedStudent = try #require(try await store.listStudents().first)

        #expect(savedGuardian.address == "123 Main Street, Irvine, CA 92618")
        #expect(savedStudent.birthDate == birthDate)
    }

    @Test("Guardian link codes are one-time display values")
    func guardianLinkCode() async throws {
        let guardian = Guardian(displayName: "Family")
        let store = PreviewMasterDanceStore(
            data: PreviewData(guardians: [guardian])
        )

        let issued = try await store.issueGuardianLinkCode(guardianID: guardian.id)
        let updated = try #require(
            try await store.listGuardians(studentID: nil).first
        )

        #expect(issued.guardianID == guardian.id)
        #expect(issued.code.hasPrefix("MD-"))
        #expect(updated.activeLinkCodeHint == String(issued.code.suffix(4)))
        #expect(updated.activeLinkCodeExpiresAt == issued.expiresAt)
    }

    @Test("Existing learners can be placed into a family")
    func linksExistingStudent() async throws {
        let previousGuardian = Guardian(displayName: "Previous Family")
        let guardian = Guardian(displayName: "New Family")
        let student = Student(
            guardianID: previousGuardian.id,
            displayName: "Existing",
            kind: .child
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [student], guardians: [previousGuardian, guardian])
        )

        try await store.link(studentID: student.id, to: guardian.id)
        let linked = try await store.listGuardians(studentID: student.id)
        #expect(linked.map(\.id) == [guardian.id])
        let families = try await store.listGuardians(studentID: nil)
        #expect(families.first(where: { $0.id == previousGuardian.id })?.studentIDs.isEmpty == true)
    }

    @Test("Appearance retains all requested modes")
    func appearanceModes() {
        #expect(Set(AppearancePreference.allCases) == [.system, .light, .dark])
    }

    @Test("Preview data ships a native text agreement")
    func previewAgreement() {
        let data = PreviewData.masterDanceSample()
        let agreement = data.contractDocuments.first

        #expect(agreement?.status == .published)
        #expect(agreement?.storagePath.isEmpty == true)
        #expect(agreement?.bodyText.contains("系统功能测试") == true)
    }

    @Test("Publishing agreement text retires the prior version")
    func publishingAgreementRevision() async throws {
        let store = PreviewMasterDanceStore(data: .masterDanceSample())
        let term = try #require(await store.listTerms().first)
        let original = try #require(
            await store.listContractDocuments(termID: term.id)
                .first(where: { $0.status == .published })
        )

        let revision = await store.publishContractRevision(
            termID: term.id,
            title: "更新后的学员协议",
            bodyText: "这是一份用于验证版本发布流程的协议正文，内容长度足够通过系统校验。"
        )
        let documents = await store.listContractDocuments(termID: term.id)

        #expect(revision.version == "v2")
        #expect(revision.status == .published)
        #expect(documents.first(where: { $0.id == original.id })?.status == .retired)
        #expect(documents.filter { $0.status == .published }.map(\.id) == [revision.id])
    }

    @Test("Legacy cached contracts decode without agreement text")
    func legacyContractDecoding() throws {
        let termID = TermID()
        let documentID = ContractDocumentID()
        let json = """
        {
          "id": { "rawValue": "\(documentID.rawValue.uuidString)" },
          "termID": { "rawValue": "\(termID.rawValue.uuidString)" },
          "version": "legacy",
          "title": "Legacy PDF",
          "storagePath": "contracts/legacy.pdf",
          "status": "retired",
          "publishedAt": null
        }
        """

        let decoded = try JSONDecoder().decode(ContractDocument.self, from: Data(json.utf8))

        #expect(decoded.bodyText.isEmpty)
        #expect(decoded.storagePath == "contracts/legacy.pdf")
    }

    @Test("Legacy cached contract consents decode without signature images")
    func legacyContractConsentDecoding() throws {
        let consentID = ContractConsentID()
        let termID = TermID()
        let json = """
        {
          "id": { "rawValue": "\(consentID.rawValue.uuidString)" },
          "termID": { "rawValue": "\(termID.rawValue.uuidString)" },
          "contractVersion": "v1",
          "signerKind": "guardian",
          "signerDisplayName": "Legacy Guardian",
          "consentedAt": 0
        }
        """

        let decoded = try JSONDecoder().decode(ContractConsent.self, from: Data(json.utf8))

        #expect(decoded.signaturePNG == nil)
        #expect(decoded.signerDisplayName == "Legacy Guardian")
    }

    @Test("Administrator leave requests support create, update, and delete")
    func leaveRequestCRUD() async throws {
        let store = PreviewMasterDanceStore()
        var request = LeaveRequest(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            source: .administrator,
            submittedAt: Date(),
            note: "Called front desk"
        )

        await store.save(leaveRequest: request)
        #expect(await store.listLeaveRequests(sessionID: nil, studentID: nil) == [request])

        request.sessionID = ClassSessionID()
        request.studentID = StudentID()
        request.status = .approved
        request.resolvedAt = Date()
        request.note = "Approved by administrator"
        await store.save(leaveRequest: request)

        let updated = await store.listLeaveRequests(
            sessionID: request.sessionID,
            studentID: request.studentID
        )
        #expect(updated == [request])

        await store.deleteLeaveRequest(id: request.id)
        #expect(await store.listLeaveRequests(sessionID: nil, studentID: nil).isEmpty)
    }

    @Test("Custom course references persist and sessions override defaults")
    func customCourseReferences() async throws {
        let term = Term(
            name: "Term",
            startsOn: .distantPast,
            endsOn: .distantFuture,
            status: .open
        )
        let category = CourseCategory(name: "User Defined Category")
        let ageGroup = AgeGroup(name: "User Defined Ages")
        let primaryRoom = Room(name: "Room One")
        let alternateRoom = Room(name: "Room Two")
        let primaryInstructor = Instructor(displayName: "Primary")
        let substitute = Instructor(displayName: "Substitute")
        let courseType = CourseType(name: "Custom Group", isPrivate: false)
        let course = Course(
            termID: term.id,
            name: "User Defined Course Name",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: primaryRoom.id,
            defaultInstructorID: primaryInstructor.id,
            courseTypeID: courseType.id,
            format: .group
        )
        let session = ClassSession(
            courseID: course.id,
            startsAt: .distantPast,
            endsAt: .distantFuture,
            instructorOverrideID: substitute.id,
            roomOverrideID: alternateRoom.id
        )
        let store = PreviewMasterDanceStore()
        let holiday = TermHoliday(
            termID: term.id,
            name: "Break",
            startsOn: Date(),
            endsOn: Date()
        )

        try await store.save(term: term)
        try await store.save(termHoliday: holiday)
        try await store.save(courseCategory: category)
        try await store.save(courseType: courseType)
        try await store.save(ageGroup: ageGroup)
        try await store.save(room: primaryRoom)
        try await store.save(room: alternateRoom)
        try await store.save(instructor: primaryInstructor)
        try await store.save(instructor: substitute)
        try await store.save(course: course)
        try await store.save(session: session)

        let categories = try await store.listCourseCategories()
        let ageGroups = try await store.listAgeGroups()
        let rooms = try await store.listRooms()
        let instructors = try await store.listInstructors()
        let courses = try await store.listCourses(termID: term.id)
        let sessions = try await store.listSessions(courseID: course.id)

        #expect(categories == [category])
        #expect(ageGroups == [ageGroup])
        #expect(rooms == [primaryRoom, alternateRoom])
        #expect(instructors == [primaryInstructor, substitute])
        #expect(courses == [course])
        #expect(sessions == [session])

        await #expect(throws: PreviewRepositoryError.recordInUse("这位老师已被课程或课次使用，不能删除。")) {
            try await store.deleteInstructor(id: substitute.id)
        }
        #expect(try await store.listInstructors() == [primaryInstructor, substitute])
    }

    @Test("Each learner belongs to exactly one family")
    func learnerMovesInsteadOfDuplicatingFamilyLinks() async throws {
        let first = Guardian(displayName: "First Family")
        let second = Guardian(displayName: "Second Family")
        let learner = Student(guardianID: first.id, displayName: "Learner", kind: .child)
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [learner], guardians: [first, second])
        )

        try await store.link(studentID: learner.id, to: second.id)

        #expect(try await store.listGuardians(studentID: learner.id).map(\.id) == [second.id])
        let savedLearner = try #require(try await store.listStudents().first)
        #expect(savedLearner.guardianID == second.id)
    }

    @Test("Referenced records cannot be deleted but can be updated")
    func protectsReferencedRecordsAndPropagatesEdits() async throws {
        let term = Term(name: "Term", startsOn: .distantPast, endsOn: .distantFuture, status: .open)
        let category = CourseCategory(name: "Ballet")
        let ageGroup = AgeGroup(name: "Children")
        let room = Room(name: "Large Room")
        let instructor = Instructor(displayName: "Teacher")
        let courseType = CourseType(name: "Group", isPrivate: false)
        let course = Course(
            termID: term.id,
            name: "Technique",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            courseTypeID: courseType.id,
            format: .group
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(
                terms: [term],
                courseCategories: [category],
                courseTypes: [courseType],
                ageGroups: [ageGroup],
                rooms: [room],
                instructors: [instructor],
                courses: [course]
            )
        )

        await #expect(throws: PreviewRepositoryError.recordInUse("这个课程种类已被课程使用，不能删除。")) {
            try await store.deleteCourseType(id: courseType.id)
        }

        var updatedType = courseType
        updatedType.name = "Private"
        updatedType.isPrivate = true
        try await store.save(courseType: updatedType)

        let savedCourse = try #require(try await store.listCourses(termID: term.id).first)
        #expect(savedCourse.courseTypeID == updatedType.id)
        #expect(savedCourse.format == .privateLesson)
        #expect(try await store.listCourseTypes() == [updatedType])
    }

    @Test("Holidays must stay inside their term")
    func validatesTermHolidayRange() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startsOn = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
        )
        let endsOn = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))
        )
        let term = Term(name: "Fall", startsOn: startsOn, endsOn: endsOn, status: .open)
        let store = PreviewMasterDanceStore(data: PreviewData(terms: [term]))
        let validHoliday = TermHoliday(
            termID: term.id,
            name: "Thanksgiving",
            startsOn: try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))),
            endsOn: try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 29)))
        )
        try await store.save(termHoliday: validHoliday)

        let invalidHoliday = TermHoliday(
            termID: term.id,
            name: "Outside",
            startsOn: startsOn,
            endsOn: .distantFuture
        )
        await #expect(throws: PreviewRepositoryError.holidayOutsideTerm) {
            try await store.save(termHoliday: invalidHoliday)
        }
        #expect(try await store.listTermHolidays(termID: term.id) == [validHoliday])
    }

    @Test("A course needs a configured holiday before entering a term")
    func requiresHolidayBeforeCreatingOrMovingCourse() async throws {
        let term = Term(name: "Fall", startsOn: .distantPast, endsOn: .distantFuture, status: .draft)
        let secondTerm = Term(name: "Spring", startsOn: .distantPast, endsOn: .distantFuture, status: .draft)
        let course = Course(
            termID: term.id,
            name: "Technique",
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: RoomID(),
            defaultInstructorID: InstructorID(),
            courseTypeID: CourseTypeID(),
            format: .group
        )
        let store = PreviewMasterDanceStore(data: PreviewData(terms: [term, secondTerm]))

        await #expect(throws: PreviewRepositoryError.termRequiresHoliday) {
            try await store.save(course: course)
        }

        try await store.save(
            termHoliday: TermHoliday(
                termID: term.id,
                name: "Break",
                startsOn: Date(),
                endsOn: Date()
            )
        )
        try await store.save(course: course)

        var movedCourse = course
        movedCourse.termID = secondTerm.id
        await #expect(throws: PreviewRepositoryError.termRequiresHoliday) {
            try await store.save(course: movedCourse)
        }
        #expect(try await store.listCourses(termID: term.id) == [course])
    }

    @Test("Dependencies are removable in reverse order")
    func removesDependencyChainInReverseOrder() async throws {
        let term = Term(name: "Fall", startsOn: .distantPast, endsOn: .distantFuture, status: .draft)
        let holiday = TermHoliday(
            termID: term.id,
            name: "Break",
            startsOn: Date(),
            endsOn: Date()
        )
        let course = Course(
            termID: term.id,
            name: "Technique",
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: RoomID(),
            defaultInstructorID: InstructorID(),
            courseTypeID: CourseTypeID(),
            format: .group
        )
        let session = ClassSession(
            courseID: course.id,
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3_600)
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(
                terms: [term],
                termHolidays: [holiday],
                courses: [course],
                sessions: [session]
            )
        )

        await #expect(throws: PreviewRepositoryError.recordInUse("这个学期已有课程，不能删除；请先删除或停用课程。")) {
            try await store.deleteTerm(id: term.id)
        }
        await #expect(throws: PreviewRepositoryError.recordInUse("这个假期所属学期已有课程，不能删除；请先处理课程。")) {
            try await store.deleteTermHoliday(id: holiday.id)
        }

        try await store.deleteCourse(id: course.id)
        #expect(try await store.listSessions(courseID: course.id).isEmpty)
        try await store.deleteTermHoliday(id: holiday.id)
        try await store.deleteTerm(id: term.id)
        #expect(try await store.listTerms().isEmpty)
    }

    @Test("Attendance protects its course until the record is cleared")
    func protectsCourseWithAttendance() async throws {
        let course = Course(
            termID: TermID(),
            name: "Trial Class",
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: RoomID(),
            defaultInstructorID: InstructorID(),
            courseTypeID: CourseTypeID(),
            format: .group
        )
        let session = ClassSession(
            courseID: course.id,
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3_600)
        )
        let attendance = Attendance(
            sessionID: session.id,
            studentID: StudentID(),
            status: .trial,
            recordedAt: Date()
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(courses: [course], sessions: [session], attendance: [attendance])
        )

        await #expect(throws: PreviewRepositoryError.recordInUse("这门课程已有报名、签到或请假记录，不能删除；可以将它停用。")) {
            try await store.deleteCourse(id: course.id)
        }

        try await store.deleteAttendance(id: attendance.id)
        try await store.deleteCourse(id: course.id)
        #expect(try await store.listCourses(termID: nil).isEmpty)
    }

    @Test("Unlinked class sessions can be replaced")
    func deletesUnlinkedSession() async throws {
        let session = ClassSession(
            courseID: CourseID(),
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3_600)
        )
        let store = PreviewMasterDanceStore(data: PreviewData(sessions: [session]))

        try await store.deleteSession(id: session.id)

        #expect(try await store.listSessions(courseID: session.courseID).isEmpty)
    }
}
