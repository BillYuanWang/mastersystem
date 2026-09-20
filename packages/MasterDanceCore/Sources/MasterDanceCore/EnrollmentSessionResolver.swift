import Foundation

public enum EnrollmentSessionResolver {
    public static func billableSessions(
        enrollment: Enrollment,
        sessions: [ClassSession],
        trialSessionIDs: Set<ClassSessionID> = [],
        calendar: Calendar = .current
    ) -> [ClassSession] {
        // Explicit per-session selections follow their IDs when a class is moved.
        let start = enrollment.registrationMode == .fullTerm
            ? enrollment.billingStartsOn.map(calendar.startOfDay(for:)) : nil
        return sessions.filter { session in
            session.courseID == enrollment.courseID
                && session.status != .cancelled
                && enrollment.includes(sessionID: session.id)
                && !trialSessionIDs.contains(session.id)
                && (start == nil || calendar.startOfDay(for: session.startsAt) >= start!)
        }.sorted {
            $0.startsAt == $1.startsAt ? $0.id.description < $1.id.description : $0.startsAt < $1.startsAt
        }
    }
}

public struct BillingScheduleSnapshot: Codable, Equatable, Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public let id: ClassSessionID
        public let startsAt: Date
        public let endsAt: Date
        public let room: String
        public let instructor: String

        public init(session: ClassSession, room: String, instructor: String) {
            id = session.id
            startsAt = session.startsAt
            endsAt = session.endsAt
            self.room = room
            self.instructor = instructor
        }
    }

    public let version: Int
    public let courseName: String
    public let studentName: String
    public let registrationMode: EnrollmentRegistrationMode
    public let timeZoneIdentifier: String
    public let sessions: [Session]

    public init(
        courseName: String,
        studentName: String,
        registrationMode: EnrollmentRegistrationMode,
        timeZoneIdentifier: String,
        sessions: [Session]
    ) {
        version = 1
        self.courseName = courseName
        self.studentName = studentName
        self.registrationMode = registrationMode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.sessions = sessions.sorted { $0.startsAt < $1.startsAt }
    }
}
