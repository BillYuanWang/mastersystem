import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Phased course schedule integration")
@MainActor
struct PhasedScheduleIntegrationTests {
    @Test("Metadata editing leaves actual phased sessions and linked records intact")
    func metadataDoesNotRegenerateSessions() async throws {
        let fixture = Fixture()
        let model = AppModel(repository: PreviewMasterDanceStore(data: fixture.data))
        await model.reload()
        var draft = fixture.draft
        draft.name = "Updated course"
        try await model.updateCourse(fixture.course, from: draft)
        #expect(model.sessions(forCourse: fixture.course.id) == fixture.sessions)
        #expect(model.courses.first?.name == "Updated course")
        #expect(model.enrollments == fixture.data.enrollments)
        #expect(model.attendance == fixture.data.attendance)
    }

    @Test("Rescheduling preserves enrollment and attendance IDs and frozen billing dates")
    func rescheduleKeepsReferences() async throws {
        let fixture = Fixture()
        let model = AppModel(repository: PreviewMasterDanceStore(data: fixture.data))
        await model.reload()
        let frozen = model.billingScheduleSnapshot(for: fixture.enrollment)
        var draft = fixture.draft
        draft.existingSessions?[1].startsAt.addTimeInterval(3600)
        draft.existingSessions?[1].endsAt.addTimeInterval(3600)
        try await model.updateCourse(fixture.course, from: draft)
        #expect(Set(model.sessions.map(\.id)) == Set(fixture.sessions.map(\.id)))
        #expect(model.attendance == fixture.data.attendance)
        #expect(model.enrollments == fixture.data.enrollments)
        #expect(model.courses.first?.pricingStatus == .priced)
        #expect(model.billableSessions(for: fixture.enrollment).count == 1)
        #expect(frozen.sessions.first?.startsAt == fixture.sessions[1].startsAt)
        #expect(model.billingScheduleSnapshot(for: fixture.enrollment).sessions.first?.startsAt != frozen.sessions.first?.startsAt)
    }

    @Test("Stale schedule edits are rejected instead of overwriting another client")
    func rejectsStaleSchedule() async throws {
        let fixture = Fixture()
        let store = PreviewMasterDanceStore(data: fixture.data)
        let model = AppModel(repository: store)
        await model.reload()
        var remote = fixture.sessions[0]
        remote.endsAt.addTimeInterval(600)
        await store.save(session: remote)
        await model.reload()
        var draft = fixture.draft
        draft.existingSessions?[1].endsAt.addTimeInterval(600)
        await #expect(throws: AppModelError.courseScheduleChangedRemotely) {
            try await model.updateCourse(fixture.course, from: draft)
        }
        #expect(model.sessions(forCourse: fixture.course.id)[0] == remote)
    }

    @Test("Later full-term registration and per-session registration use actual dates")
    func laterRegistrationUsesActualDates() async throws {
        let fixture = Fixture()
        let model = AppModel(repository: PreviewMasterDanceStore(data: fixture.data))
        await model.reload()
        try await model.enroll(studentID: fixture.student.id, courseID: fixture.course.id,
                               billingStartsOn: fixture.sessions[1].startsAt)
        let enrollment = try #require(model.enrollments.first)
        #expect(enrollment.registrationMode == .fullTerm)
        #expect(model.billableSessions(for: enrollment).map(\.id) == [fixture.sessions[1].id])
        await #expect(throws: AppModelError.noBillableSessions) {
            try await model.enroll(studentID: fixture.student.id, courseID: fixture.course.id,
                                   billingStartsOn: fixture.term.endsOn.addingTimeInterval(86400))
        }
    }

    private struct Fixture {
        let term = Term(name: "Autumn", startsOn: Self.date("2026-08-17"), endsOn: Self.date("2026-12-20"), status: .open)
        let type = CourseType(name: "Group", isPrivate: false)
        let age = AgeGroup(name: "6-8")
        let room = Room(name: "Small room")
        let instructor = Instructor(displayName: "Instructor")
        let student = Student(guardianID: GuardianID(), displayName: "Learner", kind: .child)
        let courseID = CourseID()
        let firstID = ClassSessionID()
        let secondID = ClassSessionID()
        let enrollmentID = EnrollmentID()
        let attendanceID = AttendanceID()
        let categoryID = CourseCategoryID()

        var course: Course {
            Course(id: courseID, termID: term.id, name: "Dance", categoryID: categoryID,
                   ageGroupID: age.id, defaultRoomID: room.id, defaultInstructorID: instructor.id,
                   courseTypeID: type.id, format: .group, pricingStatus: .priced,
                   unitPriceCents: 3500, dropInUnitPriceCents: 4000)
        }
        var sessions: [ClassSession] {
            [(firstID, "2026-08-23"), (secondID, "2026-09-12")].map { id, day in
                ClassSession(id: id, courseID: courseID, startsAt: Self.date(day), endsAt: Self.date(day).addingTimeInterval(3600), status: .scheduled)
            }
        }
        var enrollment: Enrollment {
            Enrollment(id: enrollmentID, termID: term.id, courseID: courseID, studentID: student.id, enrolledAt: term.startsOn,
                       registrationMode: .perSession, selectedSessionIDs: [secondID],
                       pricingStatus: .ready, billingStartsOn: sessions[1].startsAt, unitPriceCents: 4000)
        }
        var data: PreviewData {
            PreviewData(terms: [term], courseTypes: [type], ageGroups: [age], rooms: [room], instructors: [instructor],
                        courses: [course], sessions: sessions, students: [student], enrollments: [enrollment],
                        attendance: [Attendance(id: attendanceID, sessionID: secondID, studentID: student.id, status: .present, recordedAt: term.startsOn)])
        }
        var draft: CourseCreationDraft {
            var draft = CourseCreationDraft()
            draft.name = course.name
            draft.termID = term.id
            draft.ageGroupID = age.id
            draft.roomID = room.id
            draft.instructorID = instructor.id
            draft.courseTypeID = type.id
            draft.pricingStatus = .priced
            draft.unitPriceText = "35"
            draft.dropInUnitPriceText = "40"
            draft.existingSessions = sessions
            draft.sourceSessions = sessions
            return draft
        }
        static func date(_ day: String) -> Date {
            ISO8601DateFormatter().date(from: day + "T18:00:00Z")!
        }
    }
}
