#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct AttendanceWorkspaceView: View {
    let model: AppModel

    @State private var selectedDate = Date()
    @State private var selectedSessionID: ClassSessionID?
    @State private var searchText = ""

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "签到", english: "ATTENDANCE")
                Spacer()
                DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                TextField("搜索学生", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(MDType.compact)
                    .frame(width: 160)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 0) {
                sessionList(theme: theme)
                    .frame(width: 260)

                Rectangle().fill(theme.separator).frame(width: 1)

                roster(theme: theme)
            }
        }
        .background(theme.background)
        .task(id: model.sessions.count) {
            if let focused = model.focusedSessionID, let session = model.session(id: focused) {
                selectedDate = session.startsAt
                selectedSessionID = focused
                model.focusedSessionID = nil
            } else if selectedSessionID == nil {
                selectedSessionID = sessionsForDate.first?.id
            }
        }
        .onChange(of: selectedDate) { _, _ in
            selectedSessionID = sessionsForDate.first?.id
        }
    }

    private func sessionList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("当日课程")
                    .font(MDType.bodyStrong)
                Spacer()
                Text("\(sessionsForDate.count)")
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(theme.subtleSurface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sessionsForDate) { session in
                        Button {
                            selectedSessionID = session.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.course(id: session.courseID)?.name ?? "课程")
                                    .font(MDType.bodyStrong)
                                HStack {
                                    Text(session.startsAt.formatted(date: .omitted, time: .shortened))
                                    Text(model.effectiveRoom(for: session)?.name ?? "")
                                }
                                .font(MDType.compact)
                                .foregroundStyle(theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedSessionID == session.id ? theme.accent.opacity(0.12) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .background(theme.surface)
    }

    @ViewBuilder
    private func roster(theme: MDTheme) -> some View {
        if let selectedSessionID, let session = model.session(id: selectedSessionID), let course = model.course(id: session.courseID) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(MDType.bodyStrong)
                        Text(session.startsAt.formatted(date: .long, time: .shortened))
                            .font(MDType.mono)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Text("\(presentCount(session))/\(courseRoster(course).count)")
                        .font(MDType.monoStrong)
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)

                Divider()

                HStack(spacing: 0) {
                    attendanceHeader("学生", width: 190)
                    attendanceHeader("状态", width: 360)
                    attendanceHeader("记录时间", width: 170)
                    Spacer()
                }
                .frame(height: 34)
                .background(theme.subtleSurface)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRoster(course)) { enrollment in
                            AttendanceRow(
                                model: model,
                                session: session,
                                enrollment: enrollment
                            )
                            Divider()
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "当天没有课程",
                systemImage: "checkmark.circle",
                description: Text("可以选择其他日期补录签到。")
            )
        }
    }

    private var sessionsForDate: [ClassSession] {
        model.sessions.filter { Calendar.masterDance.isDate($0.startsAt, inSameDayAs: selectedDate) }
    }

    private func courseRoster(_ course: Course) -> [Enrollment] {
        model.enrollments(forCourse: course.id)
    }

    private func filteredRoster(_ course: Course) -> [Enrollment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let roster = courseRoster(course)
        guard !query.isEmpty else { return roster }
        return roster.filter {
            model.student(id: $0.studentID)?.displayName.localizedCaseInsensitiveContains(query) == true
        }
    }

    private func presentCount(_ session: ClassSession) -> Int {
        model.attendance.filter {
            $0.sessionID == session.id && ($0.status == .present || $0.status == .makeup)
        }.count
    }
}

private struct AttendanceRow: View {
    let model: AppModel
    let session: ClassSession
    let enrollment: Enrollment

    @State private var isSaving = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let record = model.attendance.first {
            $0.sessionID == session.id && $0.studentID == enrollment.studentID
        }
        HStack(spacing: 0) {
            Text(model.student(id: enrollment.studentID)?.displayName ?? "学生")
                .font(MDType.bodyStrong)
                .frame(width: 190, alignment: .leading)
                .padding(.leading, 10)

            HStack(spacing: 6) {
                statusButton(.present, current: record?.status, color: theme.success)
                statusButton(.excused, current: record?.status, color: theme.warning)
                statusButton(.absent, current: record?.status, color: theme.danger)
                statusButton(.makeup, current: record?.status, color: theme.accent)
            }
            .frame(width: 360, alignment: .leading)
            .padding(.leading, 10)

            Text(record?.recordedAt.formatted(date: .omitted, time: .shortened) ?? "—")
                .font(MDType.mono)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 170, alignment: .leading)
                .padding(.leading, 10)

            Spacer()
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 12)
            }
        }
        .frame(minHeight: 42)
    }

    private func statusButton(_ status: AttendanceStatus, current: AttendanceStatus?, color: Color) -> some View {
        Button {
            isSaving = true
            Task {
                try? await model.recordAttendance(
                    sessionID: session.id,
                    studentID: enrollment.studentID,
                    status: status
                )
                isSaving = false
            }
        } label: {
            Label(statusLabel(status), systemImage: current == status ? "checkmark.circle.fill" : "circle")
                .font(MDType.compact)
                .foregroundStyle(current == status ? color : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func statusLabel(_ status: AttendanceStatus) -> String {
        switch status {
        case .present: "出勤"
        case .excused: "请假"
        case .absent: "缺席"
        case .makeup: "补课"
        }
    }
}

private func attendanceHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .font(MDType.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
