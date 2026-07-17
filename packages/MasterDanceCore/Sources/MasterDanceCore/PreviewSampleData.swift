import Foundation

private struct PreviewCourseSpecification {
    let name: String
    let categoryIndex: Int
    let ageGroupIndex: Int
    let roomIndex: Int
    let instructorIndex: Int
    let format: CourseFormat
    let weekday: Int
    let startTime: SessionClockTime
    let endTime: SessionClockTime
}

public extension PreviewData {
    static func masterDanceSample(now: Date = Date()) -> PreviewData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_US")
        calendar.timeZone = .current

        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let currentMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let termStart = calendar.date(byAdding: .day, value: -7, to: currentMonday) ?? currentMonday
        let termEnd = calendar.date(byAdding: .day, value: 15 * 7 + 6, to: termStart) ?? termStart
        let year = calendar.component(.year, from: now)

        let term = Term(
            name: "\(year) 秋季",
            startsOn: termStart,
            endsOn: termEnd,
            status: .open
        )

        let categories = ["芭蕾", "中国舞", "基本功", "爵士", "现代舞", "街舞"].map {
            CourseCategory(name: $0)
        }
        let ageGroups = ["5–7 岁", "7–12 岁", "青少年", "成人"].map {
            AgeGroup(name: $0)
        }
        let rooms = [Room(name: "大教室"), Room(name: "小教室")]
        let instructors = ["林老师", "王老师", "陈老师", "李老师", "周老师", "赵老师", "孙老师"].map {
            Instructor(displayName: $0)
        }

        let specifications = [
            PreviewCourseSpecification(name: "芭蕾基础", categoryIndex: 0, ageGroupIndex: 1, roomIndex: 0, instructorIndex: 0, format: .group, weekday: 2, startTime: .init(hour: 16, minute: 0), endTime: .init(hour: 17, minute: 15)),
            PreviewCourseSpecification(name: "中国舞初级", categoryIndex: 1, ageGroupIndex: 0, roomIndex: 1, instructorIndex: 1, format: .group, weekday: 2, startTime: .init(hour: 16, minute: 15), endTime: .init(hour: 17, minute: 15)),
            PreviewCourseSpecification(name: "成人现代舞", categoryIndex: 4, ageGroupIndex: 3, roomIndex: 0, instructorIndex: 4, format: .group, weekday: 2, startTime: .init(hour: 19, minute: 0), endTime: .init(hour: 20, minute: 30)),
            PreviewCourseSpecification(name: "舞蹈基本功", categoryIndex: 2, ageGroupIndex: 1, roomIndex: 0, instructorIndex: 2, format: .group, weekday: 3, startTime: .init(hour: 17, minute: 30), endTime: .init(hour: 18, minute: 30)),
            PreviewCourseSpecification(name: "爵士入门", categoryIndex: 3, ageGroupIndex: 2, roomIndex: 1, instructorIndex: 3, format: .group, weekday: 3, startTime: .init(hour: 16, minute: 30), endTime: .init(hour: 17, minute: 45)),
            PreviewCourseSpecification(name: "芭蕾进阶", categoryIndex: 0, ageGroupIndex: 2, roomIndex: 0, instructorIndex: 0, format: .group, weekday: 3, startTime: .init(hour: 18, minute: 45), endTime: .init(hour: 20, minute: 0)),
            PreviewCourseSpecification(name: "中国舞中级", categoryIndex: 1, ageGroupIndex: 1, roomIndex: 1, instructorIndex: 1, format: .group, weekday: 4, startTime: .init(hour: 16, minute: 15), endTime: .init(hour: 17, minute: 30)),
            PreviewCourseSpecification(name: "少儿街舞", categoryIndex: 5, ageGroupIndex: 1, roomIndex: 1, instructorIndex: 5, format: .group, weekday: 4, startTime: .init(hour: 18, minute: 0), endTime: .init(hour: 19, minute: 0)),
            PreviewCourseSpecification(name: "成人爵士", categoryIndex: 3, ageGroupIndex: 3, roomIndex: 0, instructorIndex: 3, format: .group, weekday: 4, startTime: .init(hour: 19, minute: 0), endTime: .init(hour: 20, minute: 30)),
            PreviewCourseSpecification(name: "芭蕾基础 II", categoryIndex: 0, ageGroupIndex: 1, roomIndex: 0, instructorIndex: 0, format: .group, weekday: 5, startTime: .init(hour: 16, minute: 0), endTime: .init(hour: 17, minute: 15)),
            PreviewCourseSpecification(name: "技巧私教", categoryIndex: 2, ageGroupIndex: 2, roomIndex: 1, instructorIndex: 6, format: .privateLesson, weekday: 5, startTime: .init(hour: 17, minute: 30), endTime: .init(hour: 18, minute: 30)),
            PreviewCourseSpecification(name: "现代舞提高", categoryIndex: 4, ageGroupIndex: 2, roomIndex: 0, instructorIndex: 4, format: .group, weekday: 5, startTime: .init(hour: 18, minute: 45), endTime: .init(hour: 20, minute: 0)),
            PreviewCourseSpecification(name: "中国舞基础", categoryIndex: 1, ageGroupIndex: 0, roomIndex: 0, instructorIndex: 1, format: .group, weekday: 6, startTime: .init(hour: 16, minute: 0), endTime: .init(hour: 17, minute: 15)),
            PreviewCourseSpecification(name: "拉丁基础", categoryIndex: 2, ageGroupIndex: 1, roomIndex: 1, instructorIndex: 2, format: .group, weekday: 6, startTime: .init(hour: 17, minute: 30), endTime: .init(hour: 18, minute: 30)),
            PreviewCourseSpecification(name: "爵士私教", categoryIndex: 3, ageGroupIndex: 3, roomIndex: 1, instructorIndex: 3, format: .privateLesson, weekday: 6, startTime: .init(hour: 19, minute: 0), endTime: .init(hour: 20, minute: 0))
        ]

        let courses = specifications.map { specification in
            Course(
                termID: term.id,
                name: specification.name,
                categoryID: categories[specification.categoryIndex].id,
                ageGroupID: ageGroups[specification.ageGroupIndex].id,
                defaultRoomID: rooms[specification.roomIndex].id,
                defaultInstructorID: instructors[specification.instructorIndex].id,
                format: specification.format
            )
        }

        var sessions: [ClassSession] = []
        for (course, specification) in zip(courses, specifications) {
            let plan = WeeklySessionPlan(
                courseID: course.id,
                startsOn: termStart,
                endsOn: termEnd,
                weekday: specification.weekday,
                startTime: specification.startTime,
                endTime: specification.endTime
            )
            sessions.append(contentsOf: (try? RecurringSessionBuilder.sessions(for: plan, calendar: calendar)) ?? [])
        }

        let studentNames = [
            "陈思彤", "李依依", "张若曦", "王梓涵", "刘子墨", "赵子墨",
            "周欣妍", "吴昊然", "孙可欣", "郑雨桐", "方安琪", "顾晓宁"
        ]
        let students = studentNames.enumerated().map { index, name in
            Student(displayName: name, kind: index < 10 ? .child : .adult)
        }
        let guardians = students.prefix(10).enumerated().map { index, student in
            Guardian(
                displayName: "\(student.displayName)家长",
                email: "guardian\(index + 1)@example.com",
                studentIDs: [student.id]
            )
        }

        var enrollments: [Enrollment] = []
        for (studentIndex, student) in students.enumerated() {
            var courseIndices = [0, 9]
            let rotatingCourseIndex = (studentIndex + 3) % (courses.count - 1) + 1
            if !courseIndices.contains(rotatingCourseIndex) {
                courseIndices.append(rotatingCourseIndex)
            }
            for courseIndex in courseIndices {
                enrollments.append(
                    Enrollment(
                        termID: term.id,
                        courseID: courses[courseIndex].id,
                        studentID: student.id,
                        enrolledAt: termStart
                    )
                )
            }
        }

        let currentWeekSessions = sessions
            .filter { calendar.isDate($0.startsAt, equalTo: currentMonday, toGranularity: .weekOfYear) }
            .sorted { $0.startsAt < $1.startsAt }
        let attendanceSession = currentWeekSessions.first(where: { calendar.isDateInToday($0.startsAt) }) ?? currentWeekSessions.first
        let attendance: [Attendance]
        if let firstSession = attendanceSession {
            let roster = enrollments.filter { $0.courseID == firstSession.courseID }
            attendance = roster.prefix(2).enumerated().map { index, enrollment in
                Attendance(
                    sessionID: firstSession.id,
                    studentID: enrollment.studentID,
                    enrollmentID: enrollment.id,
                    status: index == 0 ? .present : .excused,
                    recordedAt: now
                )
            }
        } else {
            attendance = []
        }

        let leaveRequests: [LeaveRequest]
        if let session = currentWeekSessions.dropFirst().first, let student = students.first {
            let enrollment = enrollments.first { $0.studentID == student.id && $0.courseID == session.courseID }
            leaveRequests = [
                LeaveRequest(
                    sessionID: session.id,
                    studentID: student.id,
                    enrollmentID: enrollment?.id,
                    source: .app,
                    status: .pending,
                    submittedAt: now,
                    note: "家庭安排"
                )
            ]
        } else {
            leaveRequests = []
        }

        let notifications = [
            NotificationRecord(
                recipientReference: students[0].id.description,
                kind: .classReminder,
                channel: .inApp,
                title: "明日课程提醒",
                body: "请准时到达教室。",
                scheduledAt: now,
                status: .pending
            )
        ]

        return PreviewData(
            terms: [term],
            courseCategories: categories,
            ageGroups: ageGroups,
            rooms: rooms,
            instructors: instructors,
            courses: courses,
            sessions: sessions,
            students: students,
            guardians: guardians,
            enrollments: enrollments,
            attendance: attendance,
            leaveRequests: leaveRequests,
            notifications: notifications
        )
    }
}
