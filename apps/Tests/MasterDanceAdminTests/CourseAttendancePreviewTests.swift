import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Schedule detail and hover roster")
@MainActor
struct CourseAttendancePreviewTests {
    @Test("All twenty enrolled learners remain in the detail roster")
    func keepsCompleteRoster() {
        let model = AppModel(repository: PreviewMasterDanceStore())
        let session = ClassSession(courseID: CourseID(), startsAt: .now, endsAt: .now.addingTimeInterval(3600))
        model.sessions = [session]
        model.students = (1...20).map {
            Student(guardianID: GuardianID(), displayName: "Learner \($0)", kind: .child)
        }
        model.enrollments = model.students.map {
            Enrollment(termID: TermID(), courseID: session.courseID, studentID: $0.id, enrolledAt: .now)
        }

        let preview = CourseAttendancePreview(model: model, session: session)

        #expect(preview.people.count == 20)
        #expect(preview.pending.count == 20)
        #expect(Set(preview.people.map(\.id)) == Set(model.students.map(\.id)))
    }

    @Test("Guests and guardian leave are included without double-counting an enrolled trial learner")
    func includesGuestsAndLeave() {
        let model = AppModel(repository: PreviewMasterDanceStore())
        let session = ClassSession(courseID: CourseID(), startsAt: .now, endsAt: .now.addingTimeInterval(3600))
        model.sessions = [session]
        model.students = (1...5).map {
            Student(guardianID: GuardianID(), displayName: "Learner \($0)", kind: .child)
        }
        model.enrollments = model.students.prefix(3).map {
            Enrollment(termID: TermID(), courseID: session.courseID, studentID: $0.id, enrolledAt: .now)
        }
        model.attendance = [
            Attendance(sessionID: session.id, studentID: model.students[0].id, status: .present, recordedAt: .now),
            Attendance(sessionID: session.id, studentID: model.students[2].id, status: .trial, recordedAt: .now),
            Attendance(sessionID: session.id, studentID: model.students[3].id, status: .makeup, recordedAt: .now),
            Attendance(sessionID: session.id, studentID: model.students[4].id, status: .trial, recordedAt: .now),
        ]
        model.leaveRequests = [
            LeaveRequest(sessionID: session.id, studentID: model.students[1].id, source: .app, submittedAt: .now)
        ]

        let preview = CourseAttendancePreview(model: model, session: session)

        #expect(preview.totalCount == 5)
        #expect(preview.attended.count == 4)
        #expect(preview.notAttended.count == 1)
        #expect(preview.notAttended.first?.status == .excused)
        #expect(preview.people.filter { $0.status == .trial }.count == 2)
        #expect(model.attendance.count == 4)
    }
}
