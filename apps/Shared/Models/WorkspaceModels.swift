import Foundation
import MasterDanceCore

enum AdminSection: String, CaseIterable, Identifiable {
    case schedule
    case courses
    case families
    case enrollments
    case receipts
    case attendance
    case requests
    case news
    case advertisements
    case contracts
    case dataCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "课表"
        case .courses: "课程"
        case .families: "家庭/学员"
        case .enrollments: "报名"
        case .receipts: "账单/收据"
        case .attendance: "签到"
        case .requests: "请假"
        case .news: "新闻"
        case .advertisements: "广告"
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
        case .receipts: "receipt"
        case .attendance: "checkmark.circle"
        case .requests: "calendar.badge.minus"
        case .news: "newspaper"
        case .advertisements: "megaphone"
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
    var pricingStatus = CoursePricingStatus.pending
    var unitPriceText = ""
    var dropInUnitPriceText = ""
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

struct NewsImageUpload: Sendable {
    var image: NewsArticleImage
    var fileData: Data?
}

struct EnrollmentSummary: Equatable {
    let termID: TermID?
    let activeStudentCount: Int
    let activeFamilyCount: Int
    let totalEnrollmentCount: Int
    let groupEnrollmentCount: Int
    let privateEnrollmentCount: Int

    static let empty = EnrollmentSummary(
        termID: nil,
        courses: [],
        students: [],
        enrollments: []
    )

    init(
        termID: TermID?,
        courses: [Course],
        students: [Student],
        enrollments: [Enrollment]
    ) {
        self.termID = termID

        let activeEnrollments = enrollments.filter {
            $0.status == .active && (termID == nil || $0.termID == termID)
        }
        let privateCourseIDs = Set(
            courses.lazy
                .filter { $0.format == .privateLesson }
                .map(\.id)
        )
        let studentsByID = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        let studentIDs = Set(activeEnrollments.map(\.studentID))
        let familyIDs = Set(studentIDs.compactMap { studentsByID[$0]?.guardianID })
        let privateCount = activeEnrollments.reduce(into: 0) { count, enrollment in
            if privateCourseIDs.contains(enrollment.courseID) {
                count += 1
            }
        }

        activeStudentCount = studentIDs.count
        activeFamilyCount = familyIDs.count
        totalEnrollmentCount = activeEnrollments.count
        privateEnrollmentCount = privateCount
        groupEnrollmentCount = activeEnrollments.count - privateCount
    }

    static func currentTerm(
        in terms: [Term],
        on date: Date = Date(),
        calendar: Calendar = .masterDance
    ) -> Term? {
        let openTerms = terms.filter { $0.status == .open }
        return preferredTerm(in: openTerms, on: date, calendar: calendar)
            ?? preferredTerm(in: terms, on: date, calendar: calendar)
    }

    private static func preferredTerm(
        in terms: [Term],
        on date: Date,
        calendar: Calendar
    ) -> Term? {
        let day = calendar.startOfDay(for: date)
        return terms.min { lhs, rhs in
            let lhsDistance = distance(from: day, to: lhs, calendar: calendar)
            let rhsDistance = distance(from: day, to: rhs, calendar: calendar)
            if lhsDistance == rhsDistance {
                return lhs.startsOn > rhs.startsOn
            }
            return lhsDistance < rhsDistance
        }
    }

    private static func distance(
        from day: Date,
        to term: Term,
        calendar: Calendar
    ) -> TimeInterval {
        let startsOn = calendar.startOfDay(for: term.startsOn)
        let endsOn = calendar.startOfDay(for: term.endsOn)
        if day < startsOn { return startsOn.timeIntervalSince(day) }
        if day > endsOn { return day.timeIntervalSince(endsOn) }
        return 0
    }
}

extension AppModel {
    var currentEnrollmentTerm: Term? {
        EnrollmentSummary.currentTerm(in: terms)
    }

    func enrollmentSummary(termID: TermID?) -> EnrollmentSummary {
        EnrollmentSummary(
            termID: termID,
            courses: courses,
            students: students,
            enrollments: enrollments
        )
    }
}

enum AppModelError: LocalizedError {
    case missingCourseFields
    case courseTermRequiresHoliday
    case invalidCourseUnitPrice
    case missingEnrollmentFields
    case missingPerSessionSelection
    case privateLessonRequiresPerSessionEnrollment
    case invalidEnrollmentBilling
    case missingBillingTerm
    case missingBillingItems
    case holidayOutsideTerm
    case invalidTermRange
    case missingGuardianName
    case missingGuardianEmail
    case invalidGuardianEmail
    case invalidGuardianSecondaryEmail
    case missingGuardianPhone
    case invalidGuardianPhone
    case missingStudentName
    case attendanceRequiresEnrollment
    case makeupRequiresSource
    case invalidMakeupSource
    case makeupSourceAlreadyUsed
    case courseTermHasEnrollments
    case courseScheduleHasRecords
    case missingNewsTitle
    case missingNewsBody
    case missingNewsAuthor
    case missingNewsCover
    case missingAdvertisementName
    case advertisementNameTooLong
    case missingAdvertisementCopy
    case advertisementCopyTooLong
    case invalidAdvertisementSlot
    case invalidAdvertisementDateRange
    case invalidAdvertisementThumbnail
    case invalidAdvertisementPoster
    case missingAdvertisementMedia
    case advertisementSlotConflict

    var errorDescription: String? {
        switch self {
        case .missingCourseFields: "请完成课程名称、学期、课程种类、年龄段、教室和老师。"
        case .courseTermRequiresHoliday: "请先为这个学期创建至少一个假期，再创建课程。"
        case .invalidCourseUnitPrice: "请输入正确的每节单价，金额最多保留两位小数。"
        case .missingEnrollmentFields: "请选择学生和课程。"
        case .missingPerSessionSelection: "按次报名至少需要选择一个具体课次。"
        case .privateLessonRequiresPerSessionEnrollment: "私课仅支持按次报名，请选择具体课次。"
        case .invalidEnrollmentBilling: "请检查报名计费起始日、单价、试课费和折扣。"
        case .missingBillingTerm: "请选择账单所属学期。"
        case .missingBillingItems: "账单至少需要一个收费项目。"
        case .invalidTermRange: "结束日期必须晚于开始日期。"
        case .holidayOutsideTerm: "假期日期必须位于所选学期内。"
        case .missingGuardianName: "请输入监护人姓名。"
        case .missingGuardianEmail: "请输入监护人邮箱。"
        case .invalidGuardianEmail: "请输入有效的监护人邮箱。"
        case .invalidGuardianSecondaryEmail: "请输入有效的额外联系邮箱，或留空。"
        case .missingGuardianPhone: "请输入监护人电话。"
        case .invalidGuardianPhone: "请输入 10 位美国电话号码。"
        case .missingStudentName: "请输入学员姓名。"
        case .attendanceRequiresEnrollment: "出勤、请假和缺席只能记录在已报名课程中。"
        case .makeupRequiresSource: "请选择这次补课对应的请假或缺席课次。"
        case .invalidMakeupSource: "所选课次不是这名学员可补的请假或缺席。"
        case .makeupSourceAlreadyUsed: "这次请假或缺席已经登记过补课。"
        case .courseTermHasEnrollments: "这门课程已有报名，不能更换学期；请先处理报名。"
        case .courseScheduleHasRecords: "这门课程已有签到、请假或按次报名记录，不能整体重排课次。"
        case .missingNewsTitle: "请输入新闻标题。"
        case .missingNewsBody: "请输入新闻正文。"
        case .missingNewsAuthor: "请输入作者。"
        case .missingNewsCover: "发布新闻前请添加一张封面图。"
        case .missingAdvertisementName: "请输入广告客户或品牌名称。"
        case .advertisementNameTooLong: "广告名称不能超过 40 个字符。"
        case .missingAdvertisementCopy: "请输入广告文字。"
        case .advertisementCopyTooLong: "广告正文不能超过 1024 个字符。"
        case .invalidAdvertisementSlot: "广告位必须在 1 到 5 之间。"
        case .invalidAdvertisementDateRange: "广告结束日期不能早于起始日期。"
        case .invalidAdvertisementThumbnail: "缩略图必须为 1:1，至少 600×600，且不超过 8 MB。"
        case .invalidAdvertisementPoster: "广告海报必须是有效图片，且不超过 8 MB。"
        case .missingAdvertisementMedia: "发布广告前需要方形缩略图和广告海报。"
        case .advertisementSlotConflict: "这个广告位在所选日期内已有其他广告。"
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
