#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct ScheduleInspectorView: View {
    let model: AppModel
    let sessionID: ClassSessionID?
    let openCourse: () -> Void
    let startAttendance: (ClassSessionID) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        Group {
            if let sessionID, let session = model.session(id: sessionID), let course = model.course(id: session.courseID) {
                inspector(session: session, course: course, theme: theme)
            } else {
                ContentUnavailableView(
                    "选择一门课",
                    systemImage: "cursorarrow.click",
                    description: Text("课程详情、报名学生和签到入口会显示在这里。")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }

    private func inspector(session: ClassSession, course: Course, theme: MDTheme) -> some View {
        let roster = model.enrollments(forCourse: course.id)
        let records = model.attendance.filter { $0.sessionID == session.id }
        let presentCount = records.filter { $0.status == .present || $0.status == .makeup }.count
        let leaveCount = records.filter { $0.status == .excused }.count

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(MDType.bodyStrong)
                                Text((model.courseType(id: course.courseTypeID)?.name ?? "课程种类").uppercased())
                                    .font(MDType.monoStrong)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            Text(course.format == .privateLesson ? "私" : "组")
                                .font(MDType.compactStrong)
                                .frame(width: 25, height: 25)
                                .overlay(Circle().stroke(theme.primaryText.opacity(0.72), lineWidth: 1))
                        }

                        Label(
                            model.effectiveInstructor(for: session)?.displayName ?? "未设置老师",
                            systemImage: "person"
                        )
                        Label(
                            session.startsAt.formatted(.dateTime.weekday(.abbreviated).month().day())
                                + "  " + sessionTime(session),
                            systemImage: "calendar"
                        )
                        Label(
                            model.effectiveRoom(for: session)?.name ?? "未设置教室",
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                    .font(MDType.compact)
                    .padding(16)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("报名学生")
                                .font(MDType.bodyStrong)
                            Spacer()
                            Text("\(roster.count)")
                                .font(MDType.monoStrong)
                                .foregroundStyle(theme.secondaryText)
                        }

                        if roster.isEmpty {
                            Text("暂无报名学生")
                                .font(MDType.compact)
                                .foregroundStyle(theme.secondaryText)
                        } else {
                            ForEach(roster.prefix(7)) { enrollment in
                                HStack(spacing: 8) {
                                    MDStatusDot(color: statusColor(for: enrollment, session: session, theme: theme))
                                    Text(model.student(id: enrollment.studentID)?.displayName ?? "学生")
                                        .font(MDType.compact)
                                    Spacer()
                                    Text(statusLabel(for: enrollment, session: session))
                                        .font(MDType.compact)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            if roster.count > 7 {
                                Text("查看全部 \(roster.count)")
                                    .font(MDType.compactStrong)
                                    .foregroundStyle(theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        inspectorRow("年龄", model.ageGroup(id: course.ageGroupID)?.name ?? "未设置", theme: theme)
                        inspectorRow("本学期", "\(model.sessions(forCourse: course.id).count) 周", theme: theme)
                        inspectorRow("状态", sessionStatus(session.status), theme: theme)

                        Text("课次由起止日期自动生成；休息周可在课程设置中单独移除。")
                            .font(MDType.compact)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("本次签到")
                                .font(MDType.bodyStrong)
                            Spacer()
                            Text("\(presentCount)/\(roster.count)")
                                .font(MDType.monoStrong)
                        }
                        ProgressView(value: Double(presentCount), total: Double(max(1, roster.count)))
                            .tint(theme.accent)
                        HStack(spacing: 12) {
                            Label("出勤 \(presentCount)", systemImage: "circle.fill")
                                .foregroundStyle(theme.success)
                            Label("请假 \(leaveCount)", systemImage: "circle.fill")
                                .foregroundStyle(theme.warning)
                        }
                        .font(MDType.compact)
                    }
                    .padding(16)
                }
            }

            Divider()

            VStack(spacing: 0) {
                Button(action: openCourse) {
                    Label("打开课程", systemImage: "books.vertical")
                        .font(MDType.body)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                Divider()
                    .padding(.leading, 16)

                Button {
                    startAttendance(session.id)
                } label: {
                    Label("开始签到", systemImage: "checkmark.circle")
                        .font(MDType.body)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private func inspectorRow(_ label: String, _ value: String, theme: MDTheme) -> some View {
        HStack {
            Text(label)
                .font(MDType.compact)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(MDType.compactStrong)
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

    private func attendanceRecord(for enrollment: Enrollment, session: ClassSession) -> Attendance? {
        model.attendance.first { $0.sessionID == session.id && $0.studentID == enrollment.studentID }
    }

    private func statusLabel(for enrollment: Enrollment, session: ClassSession) -> String {
        guard let record = attendanceRecord(for: enrollment, session: session) else { return "待签到" }
        return switch record.status {
        case .present: "出勤"
        case .absent: "缺席"
        case .excused: "请假"
        case .makeup: "补课"
        }
    }

    private func statusColor(for enrollment: Enrollment, session: ClassSession, theme: MDTheme) -> Color {
        guard let record = attendanceRecord(for: enrollment, session: session) else { return theme.secondaryText }
        return switch record.status {
        case .present, .makeup: theme.success
        case .excused: theme.warning
        case .absent: theme.danger
        }
    }
}
#endif
