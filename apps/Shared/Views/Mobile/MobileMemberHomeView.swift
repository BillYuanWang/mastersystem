#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberHomeView: View {
    let model: AppModel
    @Binding var selectedStudentID: StudentID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            if let student = selectedStudent {
                LazyVStack(alignment: .leading, spacing: 22) {
                    greeting(student: student, theme: theme)

                    nextClassSection(student: student, theme: theme)

                    summaryStrip(theme: theme)

                    upcomingSection(student: student, theme: theme)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            } else if model.isLoading {
                ProgressView("正在读取家庭资料")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                ContentUnavailableView(
                    "尚未连接学员",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("请联系教务老师确认监护人码和家庭档案。")
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
        .background(theme.background)
        .navigationTitle("Master Dance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MobileStudentPicker(students: model.students, selection: $selectedStudentID)
            }
        }
        .refreshable { await model.reload() }
    }

    private var selectedStudent: Student? {
        selectedStudentID.flatMap(model.student(id:))
    }

    private func greeting(student: Student, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(student.kind == .adult ? "你好，\(student.displayName)" : "\(student.displayName)的课程")
                .mdFont(size: 20, weight: .bold)
                .foregroundStyle(theme.primaryText)
            Text(Date().mdChineseFormatted(.dateTime.year().month().day().weekday(.wide)))
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nextClassSection(student: Student, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MobileSectionHeading("下一节课")
            if let session = model.upcomingSessions(forStudent: student.id).first {
                let course = model.course(id: session.courseID)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course?.name ?? "课程")
                                .mdFont(size: 17, weight: .bold)
                                .foregroundStyle(theme.primaryText)
                            Text(session.startsAt.mdChineseFormatted(.dateTime.weekday(.wide).month().day()))
                                .mdFont(.bodyStrong)
                                .foregroundStyle(theme.accent)
                        }
                        Spacer()
                        Text(session.startsAt.mdChineseFormatted(.dateTime.hour().minute()))
                            .mdFont(size: 16, weight: .bold, design: .monospaced)
                            .foregroundStyle(theme.primaryText)
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Label(
                            model.effectiveInstructor(for: session)?.displayName ?? "待定老师",
                            systemImage: "person.fill"
                        )
                        Label(
                            model.effectiveRoom(for: session)?.name ?? "待定教室",
                            systemImage: "door.left.hand.open"
                        )
                    }
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
                }
                .padding(14)
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
            } else {
                Text("暂无排定课程")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            }
        }
    }

    private func summaryStrip(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            summaryItem(
                value: "\(activeCourseCount)",
                label: "已报课程",
                color: theme.accent
            )
            Divider().frame(height: 42)
            summaryItem(
                value: "\(pendingLeaveCount)",
                label: "待处理请假",
                color: theme.warning
            )
            Divider().frame(height: 42)
            summaryItem(
                value: "\(unreadCount)",
                label: "未读消息",
                color: theme.success
            )
        }
        .padding(.vertical, 12)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .mdFont(size: 17, weight: .bold, design: .monospaced)
                .foregroundStyle(color)
            Text(label)
                .mdFont(.compact)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func upcomingSection(student: Student, theme: MDTheme) -> some View {
        let upcoming = Array(model.upcomingSessions(forStudent: student.id).prefix(5))
        VStack(alignment: .leading, spacing: 8) {
            MobileSectionHeading("近期课程", detail: upcoming.isEmpty ? nil : "未来 \(upcoming.count) 节")
            ForEach(upcoming) { session in
                MobileSessionRow(
                    session: session,
                    course: model.course(id: session.courseID),
                    room: model.effectiveRoom(for: session),
                    instructor: model.effectiveInstructor(for: session),
                    trailingText: session.startsAt.mdChineseFormatted(.dateTime.month().day())
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
            }
        }
    }

    private var activeCourseCount: Int {
        guard let selectedStudentID else { return 0 }
        return model.activeEnrollments(forStudent: selectedStudentID).count
    }

    private var pendingLeaveCount: Int {
        guard let selectedStudentID else { return 0 }
        return model.leaveRequests.filter {
            $0.studentID == selectedStudentID && $0.status == .pending
        }.count
    }

    private var unreadCount: Int {
        model.notifications.filter { $0.status != .read }.count
    }
}
#endif
