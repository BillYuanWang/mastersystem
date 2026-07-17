import Foundation

private enum SmokeFailure: Error {
    case failed(String)
}

@main
private struct CoreSmokeTest {
    static func main() async throws {
        let term = Term(
            name: "Smoke Term",
            startsOn: .distantPast,
            endsOn: .distantFuture,
            status: .open
        )
        let category = CourseCategory(name: "User Category")
        let ageGroup = AgeGroup(name: "User Age Group")
        let room = Room(name: "Large Studio")
        let instructor = Instructor(displayName: "Instructor")
        let course = Course(
            termID: term.id,
            name: "User Course",
            categoryID: category.id,
            ageGroupID: ageGroup.id,
            defaultRoomID: room.id,
            defaultInstructorID: instructor.id,
            format: .group
        )
        let session = ClassSession(
            courseID: course.id,
            startsAt: .distantPast,
            endsAt: .distantFuture
        )
        let student = Student(displayName: "Student", kind: .child)
        let enrollment = Enrollment(
            termID: term.id,
            courseID: course.id,
            studentID: student.id,
            enrolledAt: .distantPast
        )
        let attendance = Attendance(
            sessionID: session.id,
            studentID: student.id,
            enrollmentID: nil,
            status: .present,
            recordedAt: .distantPast
        )
        let store = PreviewMasterDanceStore()

        await store.save(term: term)
        await store.save(courseCategory: category)
        await store.save(ageGroup: ageGroup)
        await store.save(room: room)
        await store.save(instructor: instructor)
        await store.save(course: course)
        await store.save(session: session)
        await store.save(student: student)
        await store.save(enrollment: enrollment)
        await store.save(attendance: attendance)

        guard await store.listCourseCategories() == [category] else {
            throw SmokeFailure.failed("Custom course category did not persist")
        }
        guard await store.listEnrollments(
            termID: term.id,
            courseID: course.id,
            studentID: student.id
        ) == [enrollment] else {
            throw SmokeFailure.failed("Enrollment query failed")
        }
        guard await store.listAttendance(
            sessionID: session.id,
            studentID: student.id
        ) == [attendance] else {
            throw SmokeFailure.failed("Attendance query failed")
        }

        await store.deleteEnrollment(id: enrollment.id)

        guard await store.listEnrollments(
            termID: term.id,
            courseID: nil,
            studentID: student.id
        ).isEmpty else {
            throw SmokeFailure.failed("Enrollment removal failed")
        }
        guard Set(AppearancePreference.allCases) == [.system, .light, .dark] else {
            throw SmokeFailure.failed("Appearance modes are incomplete")
        }

        try verifyRecurringSessions(courseID: course.id)
        verifyMigrationDryRun()

        print("MasterDanceCore smoke test passed")
    }

    private static func verifyRecurringSessions(courseID: CourseID) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard
            let startsOn = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)),
            let endsOn = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)),
            let excluded = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        else {
            throw SmokeFailure.failed("Could not construct recurrence dates")
        }
        let plan = WeeklySessionPlan(
            courseID: courseID,
            startsOn: startsOn,
            endsOn: endsOn,
            weekday: 2,
            startTime: SessionClockTime(hour: 16, minute: 0),
            endTime: SessionClockTime(hour: 17, minute: 15),
            excludedDates: [excluded]
        )
        let sessions = try RecurringSessionBuilder.sessions(for: plan, calendar: calendar)
        guard sessions.count == 4 else {
            throw SmokeFailure.failed("Recurring sessions did not honor an excluded week")
        }
    }

    private static func verifyMigrationDryRun() {
        let report = MigrationDryRunReport(
            generatedAt: .distantPast,
            sourceFingerprint: "smoke",
            summaries: [
                MigrationEntitySummary(
                    entity: .course,
                    sourceRows: 2,
                    validRows: 1,
                    skippedRows: 1,
                    proposedInserts: 1,
                    proposedUpdates: 0
                )
            ],
            issues: [
                MigrationIssue(
                    severity: .error,
                    entity: .course,
                    sourceRow: 2,
                    message: "Unknown room"
                )
            ]
        )
        precondition(!report.isReadyToApply)
        precondition(report.proposedWriteCount == 1)
    }
}
