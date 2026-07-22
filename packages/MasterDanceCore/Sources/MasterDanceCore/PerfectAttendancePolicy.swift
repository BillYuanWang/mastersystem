import Foundation

public enum PerfectAttendanceStatus: Equatable, Sendable {
    case currentPerfect
    case makeupPerfect
    case notPerfect
    case termPerfect
}

public enum PerfectAttendancePolicy {
    public static func evaluationTerm(
        from terms: [Term],
        enrollments: [Enrollment],
        studentID: StudentID,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Term? {
        let enrolledTermIDs = Set(
            enrollments
                .filter { $0.studentID == studentID && $0.status != .withdrawn }
                .map(\.termID)
        )
        let candidates = terms.filter {
            $0.status != .draft && enrolledTermIDs.contains($0.id)
        }
        let day = calendar.startOfDay(for: date)

        if let latestStarted = (
            candidates
                .filter { calendar.startOfDay(for: $0.startsOn) <= day }
                .max(by: { $0.startsOn < $1.startsOn })
        ) {
            return latestStarted
        }

        return candidates
            .filter { calendar.startOfDay(for: $0.startsOn) > day }
            .min(by: { $0.startsOn < $1.startsOn })
    }

    public static func evaluate(
        term: Term,
        enrollments: [Enrollment],
        sessions: [ClassSession],
        attendance: [Attendance],
        leaveRequests: [LeaveRequest],
        studentID: StudentID,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> PerfectAttendanceStatus? {
        let studentEnrollments = enrollments.filter {
            $0.studentID == studentID
                && $0.termID == term.id
                && $0.status != .withdrawn
        }
        guard !studentEnrollments.isEmpty else { return nil }

        let termEndExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: term.endsOn)
        ) ?? term.endsOn
        let evaluationDate = min(date, termEndExclusive)
        let baseStatus = evaluateWithinTerm(
            term: term,
            enrollments: studentEnrollments,
            sessions: sessions,
            attendance: attendance,
            leaveRequests: leaveRequests,
            studentID: studentID,
            asOf: evaluationDate,
            calendar: calendar
        )

        if date >= termEndExclusive, baseStatus != .notPerfect {
            return .termPerfect
        }
        return baseStatus
    }

    private static func evaluateWithinTerm(
        term: Term,
        enrollments: [Enrollment],
        sessions: [ClassSession],
        attendance: [Attendance],
        leaveRequests: [LeaveRequest],
        studentID: StudentID,
        asOf date: Date,
        calendar: Calendar
    ) -> PerfectAttendanceStatus {
        let termStart = calendar.startOfDay(for: term.startsOn)
        let evaluationWeekStart = startOfWeek(containing: date, calendar: calendar)
        let evaluationWeekEnd = calendar.date(byAdding: .day, value: 7, to: evaluationWeekStart) ?? date
        let enrollmentByCourse = Dictionary(uniqueKeysWithValues: enrollments.map { ($0.courseID, $0) })
        let allSessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let relevantSessions = sessions.filter { session in
            guard
                session.status != .cancelled,
                session.startsAt >= termStart,
                let enrollment = enrollmentByCourse[session.courseID]
            else { return false }
            let hasOccurred = session.startsAt < date
            let isInEvaluationWeek = session.startsAt >= evaluationWeekStart
                && session.startsAt < evaluationWeekEnd
            return enrollment.includes(sessionID: session.id)
                && session.startsAt >= enrollment.enrolledAt
                && (hasOccurred || isInEvaluationWeek)
        }
        let relevantSessionIDs = Set(relevantSessions.map(\.id))
        let studentAttendance = attendance.filter {
            $0.studentID == studentID && relevantSessionIDs.contains($0.sessionID)
        }
        let attendanceBySession = Dictionary(uniqueKeysWithValues: studentAttendance.map { ($0.sessionID, $0) })

        if studentAttendance.contains(where: { $0.status == .absent }) {
            return .notPerfect
        }

        let leaveSessionIDs = Set(
            leaveRequests
                .filter {
                    $0.studentID == studentID
                        && $0.status != .denied
                        && relevantSessionIDs.contains($0.sessionID)
                        && attendanceBySession[$0.sessionID]?.status != .present
                }
                .map(\.sessionID)
        ).union(
            studentAttendance
                .filter { $0.status == .excused }
                .map(\.sessionID)
        )

        let makeupBySourceSession = Dictionary(
            grouping: attendance.filter {
                $0.studentID == studentID
                    && $0.status == .makeup
                    && $0.makeupForSessionID != nil
            },
            by: { $0.makeupForSessionID! }
        )

        var hasLeaveInCurrentWeek = false
        for sourceSessionID in leaveSessionIDs {
            guard let sourceSession = allSessionsByID[sourceSessionID] else { continue }
            let weekStart = startOfWeek(containing: sourceSession.startsAt, calendar: calendar)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? sourceSession.endsAt

            if date >= weekEnd {
                let completedInTime = makeupBySourceSession[sourceSessionID, default: []].contains { makeup in
                    guard
                        let makeupSession = allSessionsByID[makeup.sessionID],
                        makeupSession.status != .cancelled
                    else { return false }
                    return makeupSession.startsAt < weekEnd
                }
                if !completedInTime { return .notPerfect }
            } else if date >= weekStart {
                hasLeaveInCurrentWeek = true
            }
        }

        return hasLeaveInCurrentWeek ? .makeupPerfect : .currentPerfect
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }
}
