#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct GuardianInspectorView: View {
    let model: AppModel
    let guardian: Guardian

    @State private var selectedStudentID: StudentID?
    @State private var showingLearnerEditor = false
    @State private var showingGuardianEditor = false
    @State private var editingStudent: Student?
    @State private var issuedCode: GuardianLinkCode?
    @State private var deletingGuardian = false
    @State private var deletingStudent: Student?
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                guardianSummary(theme: theme)
                    .padding(16)

                Divider()

                accountSection(theme: theme)
                    .padding(16)

                Divider()

                learnerSection(theme: theme)
                    .padding(16)

                if let selectedStudent {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selectedStudent.displayName)
                                    .mdFont(.bodyStrong)
                                Text(studentDetailSummary(selectedStudent))
                                    .mdFont(.mono)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            Button {
                                editingStudent = selectedStudent
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(MDIconButtonStyle())
                            .help("编辑学员")
                            Button {
                                deletingStudent = selectedStudent
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(MDIconButtonStyle())
                            .help("删除学员")
                        }

                        StudentCourseManagerView(model: model, student: selectedStudent)
                            .id(selectedStudent.id)
                    }
                    .padding(16)
                }
            }
        }
        .foregroundStyle(theme.primaryText)
        .background(theme.surface)
        .task(id: guardian.studentIDs) {
            chooseStudent()
        }
        .sheet(isPresented: $showingLearnerEditor) {
            LearnerEditorView(model: model, guardianID: guardian.id)
        }
        .sheet(isPresented: $showingGuardianEditor) {
            GuardianEditorView(model: model, guardian: guardian)
        }
        .sheet(item: $editingStudent) { student in
            LearnerEditorView(model: model, guardianID: guardian.id, student: student)
        }
        .sheet(item: $issuedCode) { code in
            GuardianLinkCodeSheet(code: code)
        }
        .alert("永久删除家庭？", isPresented: $deletingGuardian) {
            Button("永久删除", role: .destructive) {
                Task {
                    do {
                        try await model.deleteGuardian(id: guardian.id)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("“\(guardian.displayName)”的家庭与监护人资料删除后无法恢复。仅当帐号尚未连接、名下没有学员档案时才能删除；有关联数据时系统会阻止操作。")
        }
        .alert(
            "永久删除学员？",
            isPresented: Binding(
                get: { deletingStudent != nil },
                set: { if !$0 { deletingStudent = nil } }
            ),
            presenting: deletingStudent
        ) { student in
            Button("永久删除", role: .destructive) {
                deletingStudent = nil
                Task {
                    do {
                        try await model.deleteStudent(id: student.id)
                        selectedStudentID = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: { student in
            Text("“\(student.displayName)”的学员档案删除后无法恢复。已有报名、签到或请假记录时系统会阻止操作；这类档案请改为停用。")
        }
    }

    private var learners: [Student] {
        model.students(for: guardian.id)
    }

    private var selectedStudent: Student? {
        guard let selectedStudentID else { return nil }
        return model.student(id: selectedStudentID)
    }

    private func guardianSummary(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(guardian.displayName)
                    .mdFont(.bodyStrong)
                Spacer()
                Button {
                    showingGuardianEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑监护人")
                Button {
                    deletingGuardian = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("删除监护人")
            }

            if let email = guardian.email, !email.isEmpty {
                Label(email, systemImage: "envelope")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .textSelection(.enabled)
            }
            if let phone = guardian.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .textSelection(.enabled)
            }
            if let address = guardian.address, !address.isEmpty {
                Label(address, systemImage: "house")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if guardian.email == nil, guardian.phone == nil {
                Text("未填写联系方式")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("学员帐号")
                    .mdFont(.bodyStrong)
                Spacer()
                HStack(spacing: 6) {
                    MDStatusDot(color: guardian.isAccountLinked ? theme.success : theme.warning)
                    Text(guardian.isAccountLinked ? "已连接" : "待认领")
                        .mdFont(.compactStrong)
                }
            }

            if guardian.isAccountLinked {
                Text("监护人帐号已连接此家庭。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            } else {
                if let hint = guardian.activeLinkCodeHint {
                    HStack {
                        Text("现有码")
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                        Text("•••• \(hint)")
                            .mdFont(.monoStrong)
                        Spacer()
                        if let expiresAt = guardian.activeLinkCodeExpiresAt {
                            Text(expiresAt.formatted(date: .numeric, time: .omitted))
                                .mdFont(.mono)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }

                Button {
                    issueLinkCode()
                } label: {
                    Label(
                        guardian.activeLinkCodeHint == nil ? "生成监护人码" : "重新生成监护人码",
                        systemImage: guardian.activeLinkCodeHint == nil ? "key" : "arrow.clockwise"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
            }

            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
            }
        }
    }

    private func learnerSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("学员档案")
                    .mdFont(.bodyStrong)
                Text("\(learners.count)")
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Button {
                    showingLearnerEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("在此家庭添加学员")
            }

            if learners.isEmpty {
                Text("尚无学员档案")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            }

            ForEach(learners) { learner in
                Button {
                    selectedStudentID = learner.id
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: learner.kind == .adult ? "person" : "figure.child")
                            .frame(width: 16)
                        Text(learner.displayName)
                            .mdFont(.bodyStrong)
                            .lineLimit(1)
                        Spacer()
                        Text(learner.kind == .adult ? "成人" : "少儿")
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .background(
                        selectedStudentID == learner.id ? theme.accent.opacity(0.11) : .clear,
                        in: RoundedRectangle(cornerRadius: MDMetrics.radius)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chooseStudent() {
        if let selectedStudentID, learners.contains(where: { $0.id == selectedStudentID }) {
            return
        }
        selectedStudentID = learners.first?.id
    }

    private func studentDetailSummary(_ student: Student) -> String {
        var details = [student.kind == .adult ? "成人学员" : "少儿学员"]
        if let birthDate = student.birthDate {
            details.append("生日 \(birthDate.formatted(date: .numeric, time: .omitted))")
        }
        return details.joined(separator: " · ")
    }

    private func issueLinkCode() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                issuedCode = try await model.issueGuardianLinkCode(guardianID: guardian.id)
                isWorking = false
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}

@MainActor
struct UnassignedStudentInspectorView: View {
    let model: AppModel
    let student: Student
    let onLinked: (GuardianID) -> Void

    @State private var selectedGuardianID: GuardianID?
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(student.displayName)
                        .mdFont(.bodyStrong)
                    Text(student.kind == .adult ? "成人学员 · 待归档" : "少儿学员 · 待归档")
                        .mdFont(.mono)
                        .foregroundStyle(theme.warning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("归入家庭")
                        .mdFont(.bodyStrong)
                    Picker("监护人", selection: $selectedGuardianID) {
                        Text("选择监护人").tag(Optional<GuardianID>.none)
                        ForEach(model.guardians) { guardian in
                            Text(guardian.displayName).tag(Optional(guardian.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Button {
                        archiveStudent()
                    } label: {
                        Label("完成归档", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedGuardianID == nil || isWorking)

                    if let errorMessage {
                        Text(errorMessage)
                            .mdFont(.compact)
                            .foregroundStyle(theme.danger)
                    }
                }
                .padding(16)

                Divider()

                StudentCourseManagerView(model: model, student: student)
                    .padding(16)
            }
        }
        .foregroundStyle(theme.primaryText)
        .background(theme.surface)
        .task {
            if selectedGuardianID == nil {
                selectedGuardianID = model.guardians.first?.id
            }
        }
    }

    private func archiveStudent() {
        guard let selectedGuardianID else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.link(studentID: student.id, to: selectedGuardianID)
                onLinked(selectedGuardianID)
                isWorking = false
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
#endif
