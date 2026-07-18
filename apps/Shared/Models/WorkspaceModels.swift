import Foundation
import MasterDanceCore

enum AdminSection: String, CaseIterable, Identifiable {
    case schedule
    case setup
    case students
    case enrollments
    case attendance
    case requests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "课表"
        case .setup: "课程"
        case .students: "学生"
        case .enrollments: "报名"
        case .attendance: "签到"
        case .requests: "申请"
        }
    }

    var englishTitle: String {
        switch self {
        case .schedule: "SCHEDULE"
        case .setup: "COURSES"
        case .students: "STUDENTS"
        case .enrollments: "ENROLLMENT"
        case .attendance: "ATTENDANCE"
        case .requests: "REQUESTS"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .setup: "books.vertical"
        case .students: "person.2"
        case .enrollments: "list.bullet.rectangle"
        case .attendance: "checkmark.circle"
        case .requests: "envelope"
        }
    }
}

enum SetupSection: String, CaseIterable, Identifiable {
    case courses
    case terms
    case references

    var id: String { rawValue }

    var title: String {
        switch self {
        case .courses: "课程"
        case .terms: "学期"
        case .references: "自定义资料"
        }
    }
}

enum ReferenceKind: String, CaseIterable, Identifiable {
    case category
    case ageGroup
    case room
    case instructor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category: "课程分类"
        case .ageGroup: "年龄段"
        case .room: "教室"
        case .instructor: "授课老师"
        }
    }

    var systemImage: String {
        switch self {
        case .category: "square.grid.2x2"
        case .ageGroup: "person.2"
        case .room: "door.left.hand.open"
        case .instructor: "person.crop.rectangle"
        }
    }
}

enum RoomScope: String, CaseIterable, Identifiable {
    case both
    case large
    case small

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both: "大小教室"
        case .large: "大教室"
        case .small: "小教室"
        }
    }
}

struct CourseCreationDraft {
    var name = ""
    var termID: TermID?
    var categoryID: CourseCategoryID?
    var ageGroupID: AgeGroupID?
    var roomID: RoomID?
    var instructorID: InstructorID?
    var format = CourseFormat.group
    var startsOn = Date()
    var endsOn = Calendar.masterDance.date(byAdding: .day, value: 7 * 15, to: Date()) ?? Date()
    var weekday = 2
    var startTime = SessionClockTime(hour: 16, minute: 0)
    var endTime = SessionClockTime(hour: 17, minute: 0)
    var excludedDates: Set<Date> = []
    var notes = ""
}

enum AppModelError: LocalizedError {
    case missingCourseFields
    case missingEnrollmentFields
    case invalidTermRange
    case missingGuardianName
    case invalidGuardianEmail
    case missingStudentName

    var errorDescription: String? {
        switch self {
        case .missingCourseFields: "请完成课程名称、学期、分类、年龄段、教室和老师。"
        case .missingEnrollmentFields: "请选择学生和课程。"
        case .invalidTermRange: "结束日期必须晚于开始日期。"
        case .missingGuardianName: "请输入监护人姓名。"
        case .invalidGuardianEmail: "请输入有效的监护人邮箱。"
        case .missingStudentName: "请输入学员姓名。"
        }
    }
}

extension Calendar {
    static var masterDance: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_US")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }
}

extension Date {
    func startOfWeek(using calendar: Calendar = .masterDance) -> Date {
        let day = calendar.startOfDay(for: self)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }
}
