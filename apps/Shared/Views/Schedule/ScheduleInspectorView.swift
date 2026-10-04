#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct ScheduleInspectorView: View {
    let model: AppModel
    let sessionID: ClassSessionID?
    let isCollapsed: Bool
    let headerHeight: CGFloat
    let toggleCollapsed: () -> Void
    let openCourse: () -> Void
    let startAttendance: (ClassSessionID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mdInterfaceFontScale) private var interfaceScale

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let session = sessionID.flatMap { model.session(id: $0) }
        let course = session.flatMap { model.course(id: $0.courseID) }

        VStack(spacing: 0) {
            header(session: session, course: course, theme: theme)
                .frame(height: headerHeight)

            if !isCollapsed {
                Divider()

                if let session, let course {
                    details(session: session, course: course, theme: theme)
                } else {
                    Label("未选择课程", systemImage: "cursorarrow.click")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .foregroundStyle(theme.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.surface)
        .clipped()
        .accessibilityIdentifier("md.schedule.details")
    }

    private func header(session: ClassSession?, course: Course?, theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            Text(course?.name ?? "课程详情")
                .mdFont(.bodyStrong)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(course?.name ?? "课程详情")

            if let course {
                Text(course.format == .privateLesson ? "私" : "组")
                    .mdFont(.compactStrong)
                    .frame(width: 21, height: 21)
                    .overlay(Circle().stroke(theme.secondaryText, lineWidth: 1))
                    .accessibilityLabel(course.format == .privateLesson ? "私课" : "组课")

                Text([
                    model.courseType(id: course.courseTypeID)?.name,
                    model.ageGroup(id: course.ageGroupID)?.name
                ].compactMap { $0 }.joined(separator: " · "))
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if let session, course != nil {
                Button(action: openCourse) {
                    Label("打开课程", systemImage: "books.vertical")
                }
                .buttonStyle(MDHeaderActionButtonStyle(isActive: false))

                Button {
                    startAttendance(session.id)
                } label: {
                    Label("开始签到", systemImage: "checkmark.circle")
                }
                .buttonStyle(MDHeaderActionButtonStyle(isActive: false))
            }

            Button(action: toggleCollapsed) {
                Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(MDIconButtonStyle())
            .accessibilityLabel(isCollapsed ? "展开课程详情" : "收起课程详情")
            .help(isCollapsed ? "展开课程详情" : "收起课程详情")
        }
        .padding(.horizontal, 14)
    }

    private func details(session: ClassSession, course: Course, theme: MDTheme) -> some View {
        let preview = CourseAttendancePreview(model: model, session: session)

        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                courseInformation(session: session, course: course, theme: theme)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .frame(width: 290 * interfaceScale)

            Divider()

            ScrollView {
                roster(preview: preview, theme: theme)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .id(session.id)

            Divider()

            ScrollView {
                attendanceSummary(preview: preview, theme: theme)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .frame(width: 240 * interfaceScale)
        }
    }

    private func courseInformation(session: ClassSession, course: Course, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("课程信息")
                .mdFont(.compactStrong)

            Label(
                session.startsAt.formatted(.dateTime.month().day().weekday(.abbreviated)),
                systemImage: "calendar"
            )
            Label(sessionTime(session), systemImage: "clock")

            HStack(alignment: .top, spacing: 14) {
                Label(model.effectiveInstructor(for: session)?.displayName ?? "未设置老师", systemImage: "person")
                Label(model.effectiveRoom(for: session)?.name ?? "未设置教室", systemImage: "door.left.hand.open")
            }

            Text([
                model.terms.first(where: { $0.id == course.termID })?.name ?? "未设置学期",
                "\(model.sessions(forCourse: course.id).count) 节",
                sessionStatus(session.status)
            ].joined(separator: " · "))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .mdFont(.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roster(preview: CourseAttendancePreview, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("学员名单")
                    .mdFont(.compactStrong)
                Text("\(preview.totalCount) 人")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
            }

            if preview.people.isEmpty {
                Text("暂无学员")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140 * interfaceScale), spacing: 14)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(preview.people) { person in
                        HStack(spacing: 6) {
                            MDStatusDot(color: statusColor(person, theme: theme))
                            Text(person.nickname)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(person.statusLabel)
                                .foregroundStyle(statusColor(person, theme: theme))
                                .fixedSize()
                        }
                        .mdFont(.compact)
                        .frame(minHeight: 22)
                        .help("\(person.nickname) · \(person.statusLabel)")
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func attendanceSummary(preview: CourseAttendancePreview, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本次签到")
                    .mdFont(.compactStrong)
                Spacer()
                Text("已到 \(preview.attended.count)/\(preview.totalCount)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }

            ProgressView(value: Double(preview.attended.count), total: Double(max(1, preview.totalCount)))
                .tint(theme.success)
                .accessibilityLabel("本次已到学员")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                attendanceMetric("出勤", count: preview.people.filter { $0.status == .present }.count, color: theme.success)
                attendanceMetric("请假", count: preview.people.filter { $0.status == .excused }.count, color: theme.warning)
                attendanceMetric("缺席", count: preview.people.filter { $0.status == .absent }.count, color: theme.danger)
                attendanceMetric("待记录", count: preview.pending.count, color: theme.secondaryText)
                attendanceMetric("试课", count: preview.people.filter { $0.status == .trial }.count, color: theme.accent)
                attendanceMetric("补课", count: preview.people.filter { $0.status == .makeup }.count, color: theme.success)
                attendanceMetric("次卡", count: preview.people.filter(\.usesSessionPass).count, color: theme.warning)
            }
        }
    }

    private func attendanceMetric(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            MDStatusDot(color: color)
            Text(title)
                .mdFont(.compact)
            Spacer(minLength: 2)
            Text("\(count)")
                .mdFont(.mono)
        }
    }

    private func statusColor(_ person: CourseAttendancePerson, theme: MDTheme) -> Color {
        if person.usesSessionPass { return theme.warning }
        return switch person.status {
        case .present, .makeup: theme.success
        case .trial: theme.accent
        case .excused: theme.warning
        case .absent: theme.danger
        case nil: theme.secondaryText
        }
    }

    private func sessionTime(_ session: ClassSession) -> String {
        "\(session.startsAt.formatted(date: .omitted, time: .shortened))–\(session.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private func sessionStatus(_ status: ClassSessionStatus) -> String {
        switch status {
        case .scheduled: "已排课"
        case .cancelled: "已取消"
        case .completed: "已完成"
        }
    }
}
#endif
