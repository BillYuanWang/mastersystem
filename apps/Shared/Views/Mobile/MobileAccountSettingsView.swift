#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileAccountSettingsView: View {
    let role: AppRole
    let model: AppModel
    let accountDisplayName: String?
    @Binding var appearanceRawValue: String
    let actions: MobileMemberActionService?
    let onSignOut: (() -> Void)?

    @State private var editingGuardian: Guardian?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        Form {
            Section("账号") {
                LabeledContent("姓名") {
                    Text(accountDisplayName ?? "Master Dance 用户")
                        .mdFont(.bodyStrong)
                }
                LabeledContent("身份") {
                    Text(roleTitle)
                        .mdFont(.bodyStrong)
                }
            }

            if role != .administrator {
                Section("家庭成员") {
                    if model.students.isEmpty {
                        Text("尚未连接学员")
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(model.students) { student in
                            HStack {
                                Image(systemName: student.kind == .adult ? "person.fill" : "figure.child")
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 24)
                                Text(student.displayName)
                                    .mdFont(.bodyStrong)
                                Spacer()
                                Text(student.kind == .adult ? "成人" : "少儿")
                                    .mdFont(.compact)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }

                if let guardian = model.guardians.first, actions != nil {
                    Section("联系方式") {
                        LabeledContent("邮箱", value: guardian.email ?? "")
                        LabeledContent("电话", value: guardian.phone ?? "")
                        Button {
                            editingGuardian = guardian
                        } label: {
                            Label("修改联系方式", systemImage: "pencil")
                        }
                    }
                }
            }

            Section("外观") {
                Picker("主题", selection: $appearanceRawValue) {
                    Text("跟随系统").tag(AppearancePreference.system.rawValue)
                    Text("浅色").tag(AppearancePreference.light.rawValue)
                    Text("深色").tag(AppearancePreference.dark.rawValue)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button(role: .destructive) {
                    onSignOut?()
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .disabled(onSignOut == nil)
            }
        }
        .navigationTitle("我的")
        .sheet(item: $editingGuardian) { guardian in
            if let actions {
                MobileGuardianContactEditor(
                    model: model,
                    actions: actions,
                    guardian: guardian
                )
                .presentationDetents([.medium])
            }
        }
    }

    private var roleTitle: String {
        switch role {
        case .administrator: "教务老师"
        case .guardian: "监护人"
        case .adultStudent: "成人学员"
        }
    }
}

@MainActor
private struct MobileGuardianContactEditor: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let guardian: Guardian

    @State private var email: String
    @State private var phone: String
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, actions: MobileMemberActionService, guardian: Guardian) {
        self.model = model
        self.actions = actions
        self.guardian = guardian
        _email = State(initialValue: guardian.email ?? "")
        _phone = State(initialValue: guardian.phone ?? "")
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            Form {
                Section {
                    TextField("name@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                    TextField("+1 (000) 000-0000", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.danger)
                    }
                }
            }
            .navigationTitle("联系方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func save() {
        errorMessage = nil
        Task {
            do {
                try await actions.updateGuardianContact(
                    guardianID: guardian.id,
                    email: email,
                    phone: phone
                )
                try model.applyLocalGuardianContact(
                    id: guardian.id,
                    email: email,
                    phone: phone
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
