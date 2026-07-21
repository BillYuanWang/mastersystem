#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberLeaveView: View {
    let model: AppModel
    let actions: MobileMemberActionService
    @Binding var selectedStudentID: StudentID?

    @SceneStorage("master-dance.mobile.leave.selected-date")
    private var selectedDateStorage = Calendar.masterDance
        .startOfDay(for: Date())
        .timeIntervalSinceReferenceDate
    @State private var selectedSessionID: ClassSessionID?
    @State private var lateSession: ClassSession?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                leaveHistorySection(theme: theme)
                upcomingLeaveSection(theme: theme)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(theme.background)
        .navigationTitle("请假")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MobileStudentPicker(students: model.students, selection: $selectedStudentID)
            }
        }
        .refreshable { await model.reload() }
        .sheet(item: selectedSessionBinding) { session in
            if let studentID = selectedStudentID {
                MobileLeaveRequestSheet(
                    model: model,
                    actions: actions,
                    studentID: studentID,
                    session: session,
                    existingRequest: request(for: session)
                )
                .presentationDetents([.medium, .large])
            }
        }
        .alert(
            "已超过线上请假时间",
            isPresented: Binding(
                get: { lateSession != nil },
                set: { if !$0 { lateSession = nil } }
            ),
            presenting: lateSession
        ) { _ in
            Button("知道了", role: .cancel) {}
        } message: { session in
            Text(guardianLeaveDeadlineMessage(for: session))
        }
    }

    @ViewBuilder
    private func leaveHistorySection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MobileSectionHeading(
                "请假记录",
                detail: requests.isEmpty ? nil : "\(requests.count) 条"
            )

            if requests.isEmpty {
                Text("暂无请假记录")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(
                        theme.subtleSurface,
                        in: RoundedRectangle(cornerRadius: MDMetrics.radius)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                        leaveRequestRow(request, theme: theme)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                        if index < requests.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(
                    theme.raisedSurface,
                    in: RoundedRectangle(cornerRadius: MDMetrics.radius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func upcomingLeaveSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MobileSectionHeading("接下来课程")

            DatePicker(
                "选择请假日期",
                selection: selectedDateBinding,
                in: Calendar.masterDance.startOfDay(for: Date())...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(theme.accent)
            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                theme.raisedSurface,
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.faintSeparator, lineWidth: 1)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(selectedDate.mdChineseFormatted(.dateTime.month().day().weekday(.wide)))
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(daySessions.isEmpty ? "无课程" : "\(daySessions.count) 节")
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }

            if daySessions.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "calendar.badge.minus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                    Text("这一天没有可请假的已报名课程")
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Text("请在日历中选择其他日期")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 112)
                .background(
                    theme.subtleSurface,
                    in: RoundedRectangle(cornerRadius: MDMetrics.radius)
                )
            } else {
                ForEach(daySessions) { session in
                    daySessionButton(session, theme: theme)
                }
            }
        }
    }

    private func daySessionButton(_ session: ClassSession, theme: MDTheme) -> some View {
        Button {
            if request(for: session) == nil,
               !LeaveRequestPolicy.canGuardianSubmit(for: session.startsAt) {
                lateSession = session
            } else {
                selectedSessionID = session.id
            }
        } label: {
            HStack(spacing: 10) {
                MobileSessionRow(
                    session: session,
                    course: model.course(id: session.courseID),
                    room: model.effectiveRoom(for: session),
                    instructor: model.effectiveInstructor(for: session),
                    trailingText: nil
                )

                if request(for: session) != nil {
                    MobileStatusPill(
                        title: "已请假",
                        systemImage: "checkmark.circle.fill",
                        color: theme.success
                    )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 18)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                theme.raisedSurface,
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.faintSeparator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var upcomingSessions: [ClassSession] {
        guard let selectedStudentID else { return [] }
        return model.upcomingSessions(forStudent: selectedStudentID)
            .filter { $0.status == .scheduled }
    }

    private var selectedDate: Date {
        let calendar = Calendar.masterDance
        let storedDate = calendar.startOfDay(
            for: Date(timeIntervalSinceReferenceDate: selectedDateStorage)
        )
        return max(storedDate, calendar.startOfDay(for: Date()))
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: {
                selectedDateStorage = Calendar.masterDance
                    .startOfDay(for: $0)
                    .timeIntervalSinceReferenceDate
            }
        )
    }

    private var daySessions: [ClassSession] {
        upcomingSessions.filter {
            Calendar.masterDance.isDate($0.startsAt, inSameDayAs: selectedDate)
        }
    }

    private var requests: [LeaveRequest] {
        guard let selectedStudentID else { return [] }
        return model.leaveRequests
            .filter { $0.studentID == selectedStudentID }
            .sorted { $0.submittedAt > $1.submittedAt }
    }

    private func request(for session: ClassSession) -> LeaveRequest? {
        guard let selectedStudentID else { return nil }
        return model.leaveRequest(sessionID: session.id, studentID: selectedStudentID)
    }

    private var selectedSessionBinding: Binding<ClassSession?> {
        Binding(
            get: { selectedSessionID.flatMap(model.session(id:)) },
            set: { selectedSessionID = $0?.id }
        )
    }

    private func leaveRequestRow(_ request: LeaveRequest, theme: MDTheme) -> some View {
        let session = model.session(id: request.sessionID)
        let course = session.flatMap { model.course(id: $0.courseID) }
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course?.name ?? "课程")
                    .mdFont(.bodyStrong)
                Text(session?.startsAt.mdChineseFormatted(.dateTime.year().month().day().hour().minute()) ?? "课次")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                if let note = request.note, !note.isEmpty {
                    Text(note)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            MobileStatusPill(
                title: "已请假",
                systemImage: "checkmark.circle.fill",
                color: theme.success
            )
        }
        .padding(.vertical, 3)
    }
}

@MainActor
private struct MobileLeaveRequestSheet: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let studentID: StudentID
    let session: ClassSession
    let existingRequest: LeaveRequest?

    @State private var note: String
    @State private var errorMessage: String?
    @State private var showingDeadlineAlert = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        model: AppModel,
        actions: MobileMemberActionService,
        studentID: StudentID,
        session: ClassSession,
        existingRequest: LeaveRequest?
    ) {
        self.model = model
        self.actions = actions
        self.studentID = studentID
        self.session = session
        self.existingRequest = existingRequest
        _note = State(initialValue: existingRequest?.note ?? "")
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            Form {
                Section("课次") {
                    MobileSessionRow(
                        session: session,
                        course: model.course(id: session.courseID),
                        room: model.effectiveRoom(for: session),
                        instructor: model.effectiveInstructor(for: session),
                        trailingText: session.startsAt.mdChineseFormatted(.dateTime.month().day())
                    )
                }

                Section("说明（选填）") {
                    TextField("例如：身体不适", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.danger)
                    }
                }
            }
            .navigationTitle(existingRequest == nil ? "提交请假" : "更新请假")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") { submit() }
                }
            }
            .alert("已超过线上请假时间", isPresented: $showingDeadlineAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(guardianLeaveDeadlineMessage(for: session))
            }
        }
    }

    private func submit() {
        errorMessage = nil
        guard existingRequest != nil || LeaveRequestPolicy.canGuardianSubmit(for: session.startsAt) else {
            showingDeadlineAlert = true
            return
        }
        Task {
            do {
                try await actions.submitLeave(
                    sessionID: session.id,
                    studentID: studentID,
                    note: note
                )
                model.applyLocalLeaveRequest(
                    sessionID: session.id,
                    studentID: studentID,
                    note: note
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private func guardianLeaveDeadlineMessage(for session: ClassSession) -> String {
    let classTime = session.startsAt.mdChineseFormatted(
        .dateTime.month().day().weekday(.wide).hour().minute()
    )
    let deadline = LeaveRequestPolicy.guardianDeadline(for: session.startsAt).mdChineseFormatted(
        .dateTime.month().day().weekday(.wide).hour().minute()
    )
    return "本节课开始时间：\(classTime)\n线上请假截止时间：\(deadline)（开课前 12 小时）\n当前已超过截止时间，请联系教务老师协助登记。"
}
#endif
