#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberLeaveView: View {
    let model: AppModel
    let actions: MobileMemberActionService
    @Binding var selectedStudentID: StudentID?

    @State private var selectedSessionID: ClassSessionID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        List {
            Section("接下来的课程") {
                if upcomingSessions.isEmpty {
                    Text("暂无可请假的后续课次")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(upcomingSessions.prefix(8)) { session in
                        Button {
                            selectedSessionID = session.id
                        } label: {
                            HStack {
                                MobileSessionRow(
                                    session: session,
                                    course: model.course(id: session.courseID),
                                    room: model.effectiveRoom(for: session),
                                    instructor: model.effectiveInstructor(for: session),
                                    trailingText: session.startsAt.mdChineseFormatted(.dateTime.month().day())
                                )
                                Spacer(minLength: 4)
                                if request(for: session) != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.success)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("请假记录") {
                if requests.isEmpty {
                    Text("暂无请假记录")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(requests) { request in
                        leaveRequestRow(request, theme: theme)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
    }

    private var upcomingSessions: [ClassSession] {
        guard let selectedStudentID else { return [] }
        return model.upcomingSessions(forStudent: selectedStudentID)
            .filter { $0.status == .scheduled }
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
                title: request.status.mobileTitle,
                systemImage: request.status.mobileSystemImage,
                color: request.status.mobileColor(theme: theme)
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
        }
    }

    private func submit() {
        errorMessage = nil
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
#endif
