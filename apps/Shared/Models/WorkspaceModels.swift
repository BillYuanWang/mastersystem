import Foundation
import MasterDanceCore

enum AdminSection: String, CaseIterable, Identifiable {
    case schedule
    case courses
    case families
    case enrollments
    case attendance
    case requests
    case contracts
    case dataCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "课表"
        case .courses: "课程"
        case .families: "家庭/学员"
        case .enrollments: "报名"
        case .attendance: "签到"
        case .requests: "请假/通知"
        case .contracts: "合同"
        case .dataCenter: "数据中心"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .courses: "books.vertical"
        case .families: "person.2"
        case .enrollments: "list.bullet.rectangle"
        case .attendance: "checkmark.circle"
        case .requests: "envelope"
        case .contracts: "doc.text"
        case .dataCenter: "cylinder.split.1x2"
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
    case ageGroup
    case room
    case instructor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ageGroup: "年龄段"
        case .room: "教室"
        case .instructor: "授课老师"
        }
    }

    var systemImage: String {
        switch self {
        case .ageGroup: "person.2"
        case .room: "door.left.hand.open"
        case .instructor: "person.crop.rectangle"
        }
    }
}

struct CourseCreationDraft {
    var name = ""
    var termID: TermID?
    var ageGroupID: AgeGroupID?
    var roomID: RoomID?
    var instructorID: InstructorID?
    var courseTypeID: CourseTypeID?
    var startsOn = Date()
    var endsOn = Calendar.masterDance.date(byAdding: .day, value: 7 * 15, to: Date()) ?? Date()
    var weekday = 2
    var startTime = SessionClockTime(hour: 16, minute: 0)
    var endTime = SessionClockTime(hour: 17, minute: 0)
    var excludedDates: Set<Date> = []
    var notes = ""
    var isActive = true
}

enum BackgroundSyncNotice: Equatable {
    case success(String)
    case failure(String)
}

struct BackgroundSyncPresentation: Equatable {
    var activeCount = 0
    var activeLabel: String?
    var notice: BackgroundSyncNotice?

    var isVisible: Bool {
        activeCount > 0 || notice != nil
    }
}

struct CloudActivityPresentation: Equatable {
    var activeCount = 0
    var activeLabel: String?

    var isActive: Bool {
        activeCount > 0
    }
}

enum AppModelError: LocalizedError {
    case missingCourseFields
    case courseTermRequiresHoliday
    case missingEnrollmentFields
    case holidayOutsideTerm
    case invalidTermRange
    case missingGuardianName
    case missingGuardianEmail
    case invalidGuardianEmail
    case missingGuardianPhone
    case invalidGuardianPhone
    case missingStudentName
    case attendanceRequiresEnrollment
    case courseTermHasEnrollments
    case courseScheduleHasRecords

    var errorDescription: String? {
        switch self {
        case .missingCourseFields: "请完成课程名称、学期、课程种类、年龄段、教室和老师。"
        case .courseTermRequiresHoliday: "请先为这个学期创建至少一个假期，再创建课程。"
        case .missingEnrollmentFields: "请选择学生和课程。"
        case .invalidTermRange: "结束日期必须晚于开始日期。"
        case .holidayOutsideTerm: "假期日期必须位于所选学期内。"
        case .missingGuardianName: "请输入监护人姓名。"
        case .missingGuardianEmail: "请输入监护人邮箱。"
        case .invalidGuardianEmail: "请输入有效的监护人邮箱。"
        case .missingGuardianPhone: "请输入监护人电话。"
        case .invalidGuardianPhone: "请输入 10 位美国电话号码。"
        case .missingStudentName: "请输入学员姓名。"
        case .attendanceRequiresEnrollment: "出勤、请假和缺席只能记录在已报名课程中。"
        case .courseTermHasEnrollments: "这门课程已有报名，不能更换学期；请先处理报名。"
        case .courseScheduleHasRecords: "这门课程已有签到或请假记录，不能整体重排课次。"
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
