import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Course schedule conflict detector")
struct CourseScheduleConflictDetectorTests {
    @Test("Overlapping room and instructor conflicts are reported for both courses")
    func reportsBothCourses() throws {
        let roomID = RoomID()
        let instructorID = InstructorID()
        let first = course(roomID: roomID, instructorID: instructorID)
        let second = course(roomID: roomID, instructorID: instructorID)
        let start = try #require(ISO8601DateFormatter().date(from: "2026-08-18T16:00:00Z"))
        let sessions = [
            session(courseID: first.id, startsAt: start, duration: 60),
            session(courseID: second.id, startsAt: start.addingTimeInterval(30 * 60), duration: 60),
        ]

        let result = CourseScheduleConflictDetector.conflicts(
            courses: [first, second],
            sessions: sessions
        )

        let firstConflict = try #require(result[first.id]?.first)
        let secondConflict = try #require(result[second.id]?.first)
        #expect(firstConflict.conflictingCourseID == second.id)
        #expect(secondConflict.conflictingCourseID == first.id)
        #expect(firstConflict.resources == [.room, .instructor])
        #expect(firstConflict.overlappingSessionCount == 1)
    }

    @Test("Different rooms and instructors may overlap without a warning")
    func allowsIndependentResources() throws {
        let first = course(roomID: RoomID(), instructorID: InstructorID())
        let second = course(roomID: RoomID(), instructorID: InstructorID())
        let start = try #require(ISO8601DateFormatter().date(from: "2026-08-18T16:00:00Z"))

        let result = CourseScheduleConflictDetector.conflicts(
            courses: [first, second],
            sessions: [
                session(courseID: first.id, startsAt: start, duration: 60),
                session(courseID: second.id, startsAt: start, duration: 60),
            ]
        )

        #expect(result.isEmpty)
    }

    @Test("Cancelled sessions and inactive courses do not create warnings")
    func ignoresUnavailableRows() throws {
        let roomID = RoomID()
        let instructorID = InstructorID()
        let active = course(roomID: roomID, instructorID: instructorID)
        var inactive = course(roomID: roomID, instructorID: instructorID)
        inactive.isActive = false
        let cancelledCourse = course(roomID: roomID, instructorID: instructorID)
        let start = try #require(ISO8601DateFormatter().date(from: "2026-08-18T16:00:00Z"))

        let result = CourseScheduleConflictDetector.conflicts(
            courses: [active, inactive, cancelledCourse],
            sessions: [
                session(courseID: active.id, startsAt: start, duration: 60),
                session(courseID: inactive.id, startsAt: start, duration: 60),
                session(courseID: cancelledCourse.id, startsAt: start, duration: 60, status: .cancelled),
            ]
        )

        #expect(result.isEmpty)
    }

    private func course(roomID: RoomID, instructorID: InstructorID) -> Course {
        Course(
            termID: TermID(),
            name: UUID().uuidString,
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: roomID,
            defaultInstructorID: instructorID,
            courseTypeID: CourseTypeID(),
            format: .group
        )
    }

    private func session(
        courseID: CourseID,
        startsAt: Date,
        duration: TimeInterval,
        status: ClassSessionStatus = .scheduled
    ) -> ClassSession {
        ClassSession(
            courseID: courseID,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(duration * 60),
            status: status
        )
    }
}
