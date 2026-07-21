#if os(iOS)
import Foundation
import MasterDanceCore
import SwiftUI

struct MobileStudentPicker: View {
    let students: [Student]
    @Binding var selection: StudentID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        if students.count <= 1 {
            Label(students.first?.displayName ?? "暂无学员", systemImage: "person.crop.circle")
                .mdFont(.bodyStrong)
                .foregroundStyle(students.isEmpty ? theme.secondaryText : theme.primaryText)
        } else {
            Menu {
                ForEach(students) { student in
                    Button {
                        selection = student.id
                    } label: {
                        if selection == student.id {
                            Label(student.displayName, systemImage: "checkmark")
                        } else {
                            Text(student.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                    Text(selectedStudentName)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .mdFont(.bodyStrong)
                .foregroundStyle(theme.primaryText)
            }
        }
    }

    private var selectedStudentName: String {
        students.first(where: { $0.id == selection })?.displayName
            ?? students.first?.displayName
            ?? "选择学员"
    }
}

struct MobileSessionRow: View {
    let session: ClassSession
    let course: Course?
    let room: Room?
    let instructor: Instructor?
    let trailingText: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(session.startsAt.mdChineseFormatted(.dateTime.hour().minute()))
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.primaryText)
                Text(session.endsAt.mdChineseFormatted(.dateTime.hour().minute()))
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(course?.name ?? "课程")
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                Text([instructor?.displayName, room?.name].compactMap { $0 }.joined(separator: " · "))
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                if session.status == .cancelled {
                    Label("本次停课", systemImage: "xmark.circle.fill")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.danger)
                }
            }

            Spacer(minLength: 4)

            if let trailingText {
                Text(trailingText)
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MobileStatusPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .mdFont(.compactStrong)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct MobileSectionHeading: View {
    let title: String
    let detail: String?
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .mdFont(.bodyStrong)
                .foregroundStyle(theme.primaryText)
            Spacer()
            if let detail {
                Text(detail)
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }
}

@MainActor
extension AppModel {
    func activeEnrollments(forStudent studentID: StudentID) -> [Enrollment] {
        enrollments
            .filter { $0.studentID == studentID && $0.status == .active }
            .sorted { lhs, rhs in
                let leftName = course(id: lhs.courseID)?.name ?? ""
                let rightName = course(id: rhs.courseID)?.name ?? ""
                return leftName.localizedCompare(rightName) == .orderedAscending
            }
    }

    func upcomingSessions(forStudent studentID: StudentID, from date: Date = Date()) -> [ClassSession] {
        let courseIDs = Set(activeEnrollments(forStudent: studentID).map(\.courseID))
        return sessions
            .filter {
                courseIDs.contains($0.courseID)
                    && $0.startsAt >= date
                    && $0.status == .scheduled
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func nextSession(forCourse courseID: CourseID, from date: Date = Date()) -> ClassSession? {
        sessions
            .filter { $0.courseID == courseID && $0.startsAt >= date && $0.status == .scheduled }
            .min { $0.startsAt < $1.startsAt }
    }

}

extension Date {
    func mdChineseFormatted(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(Locale(identifier: "zh_Hans_CN")))
    }
}

extension AttendanceStatus {
    var mobileTitle: String {
        switch self {
        case .present: "出勤"
        case .excused: "请假"
        case .absent: "缺席"
        case .makeup: "补课"
        case .trial: "试课"
        }
    }

    var mobileSystemImage: String {
        switch self {
        case .present: "checkmark.circle.fill"
        case .excused: "calendar.badge.minus"
        case .absent: "xmark.circle.fill"
        case .makeup: "arrow.triangle.2.circlepath"
        case .trial: "sparkles"
        }
    }

    @MainActor
    func mobileColor(theme: MDTheme) -> Color {
        switch self {
        case .present: theme.success
        case .excused: theme.warning
        case .absent: theme.danger
        case .makeup: theme.accent
        case .trial: theme.courseColor(index: 3)
        }
    }
}

#endif
