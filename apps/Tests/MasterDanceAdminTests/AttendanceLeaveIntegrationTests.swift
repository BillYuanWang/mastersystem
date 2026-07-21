import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Attendance and guardian leave integration")
struct AttendanceLeaveIntegrationTests {
    @Test("Guardian leave appears as excused without creating attendance")
    @MainActor
    func leaveDrivesEffectiveAttendanceStatus() async {
        let sessionID = ClassSessionID()
        let studentID = StudentID()
        let request = LeaveRequest(
            sessionID: sessionID,
            studentID: studentID,
            source: .app,
            submittedAt: .now
        )
        let model = AppModel(
            repository: PreviewMasterDanceStore(
                data: PreviewData(leaveRequests: [request])
            )
        )

        await model.reload()

        #expect(model.attendanceRecord(sessionID: sessionID, studentID: studentID) == nil)
        #expect(model.effectiveAttendanceStatus(sessionID: sessionID, studentID: studentID) == .excused)
    }

    @Test("Recorded attendance takes precedence over a leave request")
    @MainActor
    func attendanceOverridesLeaveForDisplay() async {
        let sessionID = ClassSessionID()
        let studentID = StudentID()
        let request = LeaveRequest(
            sessionID: sessionID,
            studentID: studentID,
            source: .app,
            submittedAt: .now
        )
        let record = Attendance(
            sessionID: sessionID,
            studentID: studentID,
            status: .present,
            recordedAt: .now
        )
        let model = AppModel(
            repository: PreviewMasterDanceStore(
                data: PreviewData(attendance: [record], leaveRequests: [request])
            )
        )

        await model.reload()

        #expect(model.effectiveAttendanceStatus(sessionID: sessionID, studentID: studentID) == .present)
    }
}
