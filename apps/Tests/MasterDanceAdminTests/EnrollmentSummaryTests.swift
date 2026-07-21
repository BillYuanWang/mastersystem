import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Enrollment summary")
struct EnrollmentSummaryTests {
    @Test("Current term prefers the nearest open term")
    func currentTermPrefersOpenTerm() {
        let calendar = testCalendar
        let today = date(2026, 7, 20, calendar: calendar)
        let summer = Term(
            name: "Summer",
            startsOn: date(2026, 6, 1, calendar: calendar),
            endsOn: date(2026, 8, 1, calendar: calendar),
            status: .closed
        )
        let fall = Term(
            name: "Fall",
            startsOn: date(2026, 8, 18, calendar: calendar),
            endsOn: date(2026, 12, 29, calendar: calendar),
            status: .open
        )
        let winter = Term(
            name: "Winter",
            startsOn: date(2027, 1, 5, calendar: calendar),
            endsOn: date(2027, 4, 30, calendar: calendar),
            status: .open
        )

        let current = EnrollmentSummary.currentTerm(
            in: [summer, winter, fall],
            on: today,
            calendar: calendar
        )

        #expect(current?.id == fall.id)
    }

    @Test("Active enrollment counts split group and private lessons")
    func activeEnrollmentCounts() {
        let calendar = testCalendar
        let enrolledAt = date(2026, 7, 20, calendar: calendar)
        let term = Term(
            name: "Fall",
            startsOn: enrolledAt,
            endsOn: date(2026, 12, 29, calendar: calendar),
            status: .open
        )
        let otherTerm = Term(
            name: "Previous",
            startsOn: date(2026, 1, 1, calendar: calendar),
            endsOn: date(2026, 5, 31, calendar: calendar),
            status: .closed
        )
        let familyID = GuardianID()
        let otherFamilyID = GuardianID()
        let firstStudent = Student(guardianID: familyID, displayName: "A", kind: .child)
        let secondStudent = Student(guardianID: familyID, displayName: "B", kind: .child)
        let otherStudent = Student(guardianID: otherFamilyID, displayName: "C", kind: .adult)
        let groupCourse = course(termID: term.id, name: "Group", format: .group)
        let privateCourse = course(termID: term.id, name: "Private", format: .privateLesson)
        let previousCourse = course(termID: otherTerm.id, name: "Previous", format: .privateLesson)
        let enrollments = [
            Enrollment(termID: term.id, courseID: groupCourse.id, studentID: firstStudent.id, enrolledAt: enrolledAt),
            Enrollment(termID: term.id, courseID: privateCourse.id, studentID: firstStudent.id, enrolledAt: enrolledAt),
            Enrollment(termID: term.id, courseID: groupCourse.id, studentID: secondStudent.id, enrolledAt: enrolledAt),
            Enrollment(
                termID: term.id,
                courseID: privateCourse.id,
                studentID: secondStudent.id,
                enrolledAt: enrolledAt,
                status: .withdrawn
            ),
            Enrollment(
                termID: otherTerm.id,
                courseID: previousCourse.id,
                studentID: otherStudent.id,
                enrolledAt: enrolledAt
            ),
        ]

        let summary = EnrollmentSummary(
            termID: term.id,
            courses: [groupCourse, privateCourse, previousCourse],
            students: [firstStudent, secondStudent, otherStudent],
            enrollments: enrollments
        )

        #expect(summary.totalEnrollmentCount == 3)
        #expect(summary.groupEnrollmentCount == 2)
        #expect(summary.privateEnrollmentCount == 1)
        #expect(summary.activeStudentCount == 2)
        #expect(summary.activeFamilyCount == 1)
    }

    @MainActor
    @Test("Remaining lesson count uses active enrollments and unfinished scheduled sessions")
    func remainingLessonCount() {
        let student = Student(guardianID: GuardianID(), displayName: "Student", kind: .child)
        let termID = TermID()
        let courses = (0..<3).map {
            course(termID: termID, name: "Course \($0)", format: .group)
        }
        let cutoff = Date(timeIntervalSince1970: 100_000)
        var sessions: [ClassSession] = []

        for index in 0..<51 {
            let startsAt = index < 8
                ? cutoff.addingTimeInterval(Double(index - 9) * 3_600)
                : cutoff.addingTimeInterval(Double(index - 7) * 3_600)
            sessions.append(
                ClassSession(
                    courseID: courses[index % courses.count].id,
                    startsAt: startsAt,
                    endsAt: startsAt.addingTimeInterval(3_000)
                )
            )
        }
        sessions.append(
            ClassSession(
                courseID: courses[0].id,
                startsAt: cutoff.addingTimeInterval(86_400),
                endsAt: cutoff.addingTimeInterval(90_000),
                status: .cancelled
            )
        )

        let model = AppModel(repository: PreviewMasterDanceStore())
        model.enrollments = courses.map {
            Enrollment(
                termID: termID,
                courseID: $0.id,
                studentID: student.id,
                enrolledAt: cutoff
            )
        }
        model.sessions = sessions

        #expect(model.remainingSessionCount(forStudent: student.id, asOf: cutoff) == 43)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func course(
        termID: TermID,
        name: String,
        format: CourseFormat
    ) -> Course {
        Course(
            termID: termID,
            name: name,
            categoryID: CourseCategoryID(),
            ageGroupID: AgeGroupID(),
            defaultRoomID: RoomID(),
            defaultInstructorID: InstructorID(),
            courseTypeID: CourseTypeID(),
            format: format
        )
    }
}
