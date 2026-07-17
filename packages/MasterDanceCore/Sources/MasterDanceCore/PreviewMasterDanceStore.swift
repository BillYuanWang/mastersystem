import Foundation

public struct PreviewData: Sendable {
    public var terms: [Term]
    public var courseCategories: [CourseCategory]
    public var ageGroups: [AgeGroup]
    public var rooms: [Room]
    public var instructors: [Instructor]
    public var courses: [Course]
    public var sessions: [ClassSession]
    public var students: [Student]
    public var guardians: [Guardian]
    public var enrollments: [Enrollment]
    public var attendance: [Attendance]
    public var leaveRequests: [LeaveRequest]
    public var contractConsents: [ContractConsent]
    public var notifications: [NotificationRecord]

    public init(
        terms: [Term] = [],
        courseCategories: [CourseCategory] = [],
        ageGroups: [AgeGroup] = [],
        rooms: [Room] = [],
        instructors: [Instructor] = [],
        courses: [Course] = [],
        sessions: [ClassSession] = [],
        students: [Student] = [],
        guardians: [Guardian] = [],
        enrollments: [Enrollment] = [],
        attendance: [Attendance] = [],
        leaveRequests: [LeaveRequest] = [],
        contractConsents: [ContractConsent] = [],
        notifications: [NotificationRecord] = []
    ) {
        self.terms = terms
        self.courseCategories = courseCategories
        self.ageGroups = ageGroups
        self.rooms = rooms
        self.instructors = instructors
        self.courses = courses
        self.sessions = sessions
        self.students = students
        self.guardians = guardians
        self.enrollments = enrollments
        self.attendance = attendance
        self.leaveRequests = leaveRequests
        self.contractConsents = contractConsents
        self.notifications = notifications
    }
}

public actor PreviewMasterDanceStore: MasterDanceRepository {
    private var data: PreviewData

    public init(data: PreviewData = PreviewData()) {
        self.data = data
    }

    public func listTerms() -> [Term] { data.terms }
    public func save(term: Term) { upsert(term, in: &data.terms) }

    public func listCourseCategories() -> [CourseCategory] { data.courseCategories }
    public func listAgeGroups() -> [AgeGroup] { data.ageGroups }
    public func listRooms() -> [Room] { data.rooms }
    public func listInstructors() -> [Instructor] { data.instructors }
    public func save(courseCategory: CourseCategory) { upsert(courseCategory, in: &data.courseCategories) }
    public func save(ageGroup: AgeGroup) { upsert(ageGroup, in: &data.ageGroups) }
    public func save(room: Room) { upsert(room, in: &data.rooms) }
    public func save(instructor: Instructor) { upsert(instructor, in: &data.instructors) }
    public func deleteCourseCategory(id: CourseCategoryID) { remove(id: id, from: &data.courseCategories) }
    public func deleteAgeGroup(id: AgeGroupID) { remove(id: id, from: &data.ageGroups) }
    public func deleteRoom(id: RoomID) { remove(id: id, from: &data.rooms) }
    public func deleteInstructor(id: InstructorID) { remove(id: id, from: &data.instructors) }

    public func listCourses(termID: TermID? = nil) -> [Course] {
        data.courses.filter { termID == nil || $0.termID == termID }
    }

    public func save(course: Course) { upsert(course, in: &data.courses) }

    public func listSessions(courseID: CourseID? = nil) -> [ClassSession] {
        data.sessions.filter { courseID == nil || $0.courseID == courseID }
    }

    public func save(session: ClassSession) { upsert(session, in: &data.sessions) }

    public func listStudents() -> [Student] { data.students }

    public func listGuardians(studentID: StudentID? = nil) -> [Guardian] {
        guard let studentID else { return data.guardians }
        return data.guardians.filter { $0.studentIDs.contains(studentID) }
    }

    public func save(student: Student) { upsert(student, in: &data.students) }
    public func save(guardian: Guardian) { upsert(guardian, in: &data.guardians) }

    public func listEnrollments(
        termID: TermID? = nil,
        courseID: CourseID? = nil,
        studentID: StudentID? = nil
    ) -> [Enrollment] {
        data.enrollments.filter {
            (termID == nil || $0.termID == termID)
                && (courseID == nil || $0.courseID == courseID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(enrollment: Enrollment) { upsert(enrollment, in: &data.enrollments) }
    public func deleteEnrollment(id: EnrollmentID) { remove(id: id, from: &data.enrollments) }

    public func listAttendance(
        sessionID: ClassSessionID? = nil,
        studentID: StudentID? = nil
    ) -> [Attendance] {
        data.attendance.filter {
            (sessionID == nil || $0.sessionID == sessionID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(attendance: Attendance) { upsert(attendance, in: &data.attendance) }

    public func listLeaveRequests(
        sessionID: ClassSessionID? = nil,
        studentID: StudentID? = nil
    ) -> [LeaveRequest] {
        data.leaveRequests.filter {
            (sessionID == nil || $0.sessionID == sessionID)
                && (studentID == nil || $0.studentID == studentID)
        }
    }

    public func save(leaveRequest: LeaveRequest) { upsert(leaveRequest, in: &data.leaveRequests) }

    public func listContractConsents(
        termID: TermID,
        enrollmentID: EnrollmentID? = nil
    ) -> [ContractConsent] {
        data.contractConsents.filter {
            $0.termID == termID && (enrollmentID == nil || $0.enrollmentID == enrollmentID)
        }
    }

    public func save(contractConsent: ContractConsent) {
        upsert(contractConsent, in: &data.contractConsents)
    }

    public func listNotifications(recipientReference: String? = nil) -> [NotificationRecord] {
        data.notifications.filter {
            recipientReference == nil || $0.recipientReference == recipientReference
        }
    }

    public func save(notification: NotificationRecord) {
        upsert(notification, in: &data.notifications)
    }

    public static func sample(now: Date = Date()) -> PreviewMasterDanceStore {
        PreviewMasterDanceStore(data: .masterDanceSample(now: now))
    }

    private func upsert<Value: Identifiable>(_ value: Value, in values: inout [Value]) where Value.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
    }

    private func remove<Value: Identifiable>(id: Value.ID, from values: inout [Value]) where Value.ID: Equatable {
        values.removeAll { $0.id == id }
    }
}
