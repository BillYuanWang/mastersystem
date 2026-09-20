import Foundation
import Testing
@testable import MasterDanceCore

@Suite("次卡")
struct SessionPassTests {
    @Test("次卡签到按最早可用卡扣次，取消签到恢复次数")
    func attendanceConsumesAndRestoresOldestPass() async throws {
        let guardian = Guardian(displayName: "Adult Family")
        let student = Student(
            guardianID: guardian.id,
            displayName: "Adult Learner",
            kind: .adult
        )
        let firstPlan = SessionPassPlan(
            name: "1 次卡",
            includedSessions: 1,
            unitPriceCents: 4_000
        )
        let secondPlan = SessionPassPlan(
            name: "2 次卡",
            includedSessions: 2,
            unitPriceCents: 4_000
        )
        let firstPass = StudentSessionPass(
            studentID: student.id,
            planID: firstPlan.id,
            issuedAt: Date(timeIntervalSince1970: 100),
            includedSessions: 1,
            unitPriceCents: 4_000
        )
        let secondPass = StudentSessionPass(
            studentID: student.id,
            planID: secondPlan.id,
            issuedAt: Date(timeIntervalSince1970: 200),
            includedSessions: 2,
            unitPriceCents: 4_000
        )
        let store = PreviewMasterDanceStore(
            data: PreviewData(
                sessionPassPlans: [firstPlan, secondPlan],
                students: [student],
                guardians: [guardian],
                studentSessionPasses: [firstPass, secondPass]
            )
        )

        let firstAttendance = passAttendance(
            studentID: student.id,
            sessionID: ClassSessionID(),
            recordedAt: Date(timeIntervalSince1970: 300)
        )
        try await store.save(attendance: firstAttendance)
        let firstUse = try #require(try await store.listSessionPassUses(
            studentSessionPassID: nil,
            studentID: student.id
        ).first)
        #expect(firstUse.studentSessionPassID == firstPass.id)

        let secondAttendance = passAttendance(
            studentID: student.id,
            sessionID: ClassSessionID(),
            recordedAt: Date(timeIntervalSince1970: 400)
        )
        try await store.save(attendance: secondAttendance)
        let usesAfterSecond = try await store.listSessionPassUses(
            studentSessionPassID: nil,
            studentID: student.id
        )
        #expect(Set(usesAfterSecond.map(\.studentSessionPassID)) == [firstPass.id, secondPass.id])

        try await store.deleteAttendance(id: firstAttendance.id)
        #expect(try await store.listSessionPassUses(
            studentSessionPassID: firstPass.id,
            studentID: nil
        ).isEmpty)

        let thirdAttendance = passAttendance(
            studentID: student.id,
            sessionID: ClassSessionID(),
            recordedAt: Date(timeIntervalSince1970: 500)
        )
        try await store.save(attendance: thirdAttendance)
        let restoredUse = try #require(try await store.listSessionPassUses(
            studentSessionPassID: firstPass.id,
            studentID: nil
        ).first)
        #expect(restoredUse.attendanceID == thirdAttendance.id)
    }

    @Test("没有可用次卡时不会伪造签到")
    func attendanceRequiresAvailablePass() async throws {
        let guardian = Guardian(displayName: "Adult Family")
        let student = Student(guardianID: guardian.id, displayName: "Adult", kind: .adult)
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [student], guardians: [guardian])
        )
        let attendance = passAttendance(
            studentID: student.id,
            sessionID: ClassSessionID(),
            recordedAt: Date()
        )

        await #expect(throws: PreviewRepositoryError.self) {
            try await store.save(attendance: attendance)
        }
        #expect(try await store.listAttendance(sessionID: nil, studentID: student.id).isEmpty)
    }

    @Test("旧缓存中没有次卡字段时默认为普通签到")
    func attendanceDecodesLegacyPayload() throws {
        let attendance = Attendance(
            sessionID: ClassSessionID(),
            studentID: StudentID(),
            status: .present,
            recordedAt: Date(timeIntervalSince1970: 1_000)
        )
        let encoded = try JSONEncoder().encode(attendance)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "usesSessionPass")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Attendance.self, from: legacyData)
        #expect(!decoded.usesSessionPass)
        #expect(!decoded.isGuestAttendance)
    }

    private func passAttendance(
        studentID: StudentID,
        sessionID: ClassSessionID,
        recordedAt: Date
    ) -> Attendance {
        Attendance(
            sessionID: sessionID,
            studentID: studentID,
            usesSessionPass: true,
            status: .present,
            recordedAt: recordedAt
        )
    }
}
