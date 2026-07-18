import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Preview repository")
struct PreviewMasterDanceStoreTests {
    @Test("Enrollment remains separate from attendance")
    func attendanceDoesNotImplyEnrollment() async throws {
        let store = PreviewMasterDanceStore()
        let student = Student(displayName: "Trial Student", kind: .child)
        let attendance = Attendance(
            sessionID: ClassSessionID(),
            studentID: student.id,
            enrollmentID: nil,
            status: .present,
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
        let courseA = Course(
            termID: term.id,
            name: "Course A",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            format: .group
        )
        let courseB = Course(
            termID: term.id,
            name: "Course B",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            format: .privateLesson
        )
        let student = Student(displayName: "Student", kind: .adult)
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
        let firstChild = StudentID()
        let secondChild = StudentID()
        let guardian = Guardian(
            displayName: "Guardian",
            studentIDs: [firstChild, secondChild]
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(guardians: [guardian])
        )

        let firstGuardians = try await store.listGuardians(studentID: firstChild)
        let secondGuardians = try await store.listGuardians(studentID: secondChild)
        #expect(firstGuardians == [guardian])
        #expect(secondGuardians == [guardian])
    }

    @Test("A family owns child and adult learner profiles")
    func familyCreatesMultipleLearners() async throws {
        let guardian = Guardian(displayName: "Family")
        let child = Student(displayName: "Child", kind: .child)
        let adult = Student(displayName: "Adult Self", kind: .adult)
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
        let guardian = Guardian(displayName: "Family")
        let student = Student(displayName: "Existing", kind: .child)
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [student], guardians: [guardian])
        )

        try await store.link(studentID: student.id, to: guardian.id)
        let linked = try await store.listGuardians(studentID: student.id)
        #expect(linked.map(\.id) == [guardian.id])
    }

    @Test("Appearance retains all requested modes")
    func appearanceModes() {
        #expect(Set(AppearancePreference.allCases) == [.system, .light, .dark])
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
        let course = Course(
            termID: term.id,
            name: "User Defined Course Name",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: primaryRoom.id,
            defaultInstructorID: primaryInstructor.id,
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

        try await store.save(courseCategory: category)
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

        try await store.deleteInstructor(id: substitute.id)
        let remainingInstructors = try await store.listInstructors()
        #expect(remainingInstructors == [primaryInstructor])
    }
}
