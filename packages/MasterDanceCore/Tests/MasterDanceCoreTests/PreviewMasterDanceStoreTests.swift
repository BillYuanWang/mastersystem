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

        #expect(
            try await store.listEnrollments(
                termID: nil,
                courseID: nil,
                studentID: student.id
            ).isEmpty
        )
        #expect(
            try await store.listAttendance(
                sessionID: nil,
                studentID: student.id
            ) == [attendance]
        )
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

        #expect(
            try await store.listEnrollments(
                termID: term.id,
                courseID: courseA.id,
                studentID: student.id
            ) == [first]
        )

        try await store.deleteEnrollment(id: first.id)

        #expect(
            try await store.listEnrollments(
                termID: term.id,
                courseID: nil,
                studentID: student.id
            ) == [second]
        )
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

        #expect(try await store.listTerms() == [updated])
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

        #expect(
            try await store.listGuardians(studentID: firstChild) == [guardian]
        )
        #expect(
            try await store.listGuardians(studentID: secondChild) == [guardian]
        )
    }

    @Test("Appearance retains all requested modes")
    func appearanceModes() {
        #expect(
            Set(AppearancePreference.allCases) == [.system, .light, .dark]
        )
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

        #expect(try await store.listCourseCategories() == [category])
        #expect(try await store.listAgeGroups() == [ageGroup])
        #expect(
            try await store.listRooms() == [primaryRoom, alternateRoom]
        )
        #expect(
            try await store.listInstructors()
                == [primaryInstructor, substitute]
        )
        #expect(try await store.listCourses(termID: term.id) == [course])
        #expect(
            try await store.listSessions(courseID: course.id) == [session]
        )

        try await store.deleteInstructor(id: substitute.id)
        #expect(
            try await store.listInstructors() == [primaryInstructor]
        )
    }
}
