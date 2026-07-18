#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseAttendanceHoverCard: View {
    let preview: CourseAttendancePreview

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.courseName)
                        .font(MDType.bodyStrong)
                    Text(preview.sessionTime)
                        .font(MDType.mono)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text("\(preview.totalCount) 人")
                    .font(MDType.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            attendanceGroup(
                title: "已到",
                systemImage: "checkmark.circle.fill",
                people: preview.attended,
                color: theme.success,
                theme: theme
            )
            attendanceGroup(
                title: "未到",
                systemImage: "xmark.circle.fill",
                people: preview.notAttended,
                color: theme.danger,
                theme: theme
            )
            attendanceGroup(
                title: "待记录",
                systemImage: "clock.fill",
                people: preview.pending,
                color: theme.secondaryText,
                theme: theme
            )
        }
        .padding(12)
        .frame(width: 330)
        .background(theme.raisedSurface)
    }

    private func attendanceGroup(
        title: String,
        systemImage: String,
        people: [CourseAttendancePerson],
        color: Color,
        theme: MDTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                Text("\(people.count)")
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .font(MDType.compactStrong)
            .foregroundStyle(color)

            if people.isEmpty {
                Text("无")
                    .font(MDType.compact)
                    .foregroundStyle(theme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 68, maximum: 100), spacing: 4)],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(people) { person in
                        HStack(spacing: 3) {
                            Text(person.nickname)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            if let marker = person.marker {
                                Text(marker)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(color)
                            }
                        }
                        .font(MDType.compactStrong)
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(
                            color.opacity(colorScheme == .dark ? 0.28 : 0.16),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(color.opacity(0.62), lineWidth: 0.7)
                        }
                        .help(person.statusLabel)
                    }
                }
            }
        }
    }
}

@MainActor
struct CourseAttendancePreview {
    let courseName: String
    let sessionTime: String
    fileprivate let attended: [CourseAttendancePerson]
    fileprivate let notAttended: [CourseAttendancePerson]
    fileprivate let pending: [CourseAttendancePerson]

    init(model: AppModel, session: ClassSession) {
        let activeEnrollments = model.enrollments(forCourse: session.courseID)
        let enrolledStudentIDs = Set(activeEnrollments.map(\.studentID))
        let sessionRecords = model.attendance.filter { $0.sessionID == session.id }
        let guestStudentIDs = Set(
            sessionRecords
                .filter { $0.status.isGuestAttendance }
                .map(\.studentID)
        )
        var recordByStudent: [StudentID: Attendance] = [:]
        for record in sessionRecords {
            recordByStudent[record.studentID] = record
        }

        let people = enrolledStudentIDs
            .union(guestStudentIDs)
            .compactMap { studentID -> CourseAttendancePerson? in
                guard let student = model.student(id: studentID) else { return nil }
                let status = recordByStudent[studentID]?.status
                return CourseAttendancePerson(
                    id: studentID,
                    nickname: student.displayName,
                    status: status,
                    presence: status.map {
                        $0.recordsPhysicalAttendance ? .attended : .notAttended
                    } ?? .pending
                )
            }
            .sorted { $0.nickname.localizedCompare($1.nickname) == .orderedAscending }

        courseName = model.course(id: session.courseID)?.name ?? "课程"
        sessionTime = "\(session.startsAt.formatted(date: .omitted, time: .shortened))–\(session.endsAt.formatted(date: .omitted, time: .shortened))"
        attended = people.filter { $0.presence == .attended }
        notAttended = people.filter { $0.presence == .notAttended }
        pending = people.filter { $0.presence == .pending }
    }

    var totalCount: Int {
        attended.count + notAttended.count + pending.count
    }
}

private struct CourseAttendancePerson: Identifiable {
    let id: StudentID
    let nickname: String
    let status: AttendanceStatus?
    let presence: CourseAttendancePresence

    var marker: String? {
        switch status {
        case .some(.trial): "试"
        case .some(.makeup): "补"
        case .some(.excused): "假"
        case .some(.absent): "缺"
        case .some(.present), .none: nil
        }
    }

    var statusLabel: String {
        switch status {
        case .some(.present): "出勤"
        case .some(.trial): "试课"
        case .some(.makeup): "补课"
        case .some(.excused): "请假"
        case .some(.absent): "缺席"
        case .none: "待记录"
        }
    }
}

private enum CourseAttendancePresence: Equatable {
    case attended
    case notAttended
    case pending
}
#endif
