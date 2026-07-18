#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

@MainActor
struct GuardianEditorView: View {
    let model: AppModel
    let original: Guardian?

    @State private var displayName: String
    @State private var email: String
    @State private var phone: String
    @State private var issuedCode: GuardianLinkCode?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, guardian: Guardian? = nil) {
        self.model = model
        original = guardian
        _displayName = State(initialValue: guardian?.displayName ?? "")
        _email = State(initialValue: guardian?.email ?? "")
        let storedPhone = guardian?.phone ?? ""
        _phone = State(initialValue: GuardianContact.formattedUSPhone(storedPhone) ?? storedPhone)
    }

    var body: some View {
        Group {
            if let issuedCode {
                GuardianLinkCodeContent(code: issuedCode) {
                    dismiss()
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    MDSectionTitle(chinese: original == nil ? "添加监护人" : "编辑监护人")

                    Form {
                        LabeledContent("监护人姓名（必填）") {
                            TextField("姓名", text: $displayName)
                        }
                        LabeledContent("邮箱（必填）") {
                            TextField("name@example.com", text: $email)
                        }
                        if !trimmedEmail.isEmpty, !emailIsValid {
                            Text("邮箱格式不正确。")
                                .font(MDType.compact)
                                .foregroundStyle(.red)
                        }
                        LabeledContent("电话（必填）") {
                            TextField("+1 (000) 000-0000", text: $phone)
                                .font(MDType.mono)
                        }
                        if !trimmedPhone.isEmpty, !phoneIsValid {
                            Text("请输入 10 位美国电话号码。")
                                .font(MDType.compact)
                                .foregroundStyle(.red)
                        }
                    }
                    .formStyle(.grouped)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(MDType.compact)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Spacer()
                        Button("取消") { dismiss() }
                        Button(original == nil ? "创建" : "保存") { save() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(!canSave || isSaving)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                if var guardian = original {
                    guardian.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guardian.email = email
                    guardian.phone = phone
                    try await model.saveGuardian(guardian)
                    dismiss()
                } else {
                    issuedCode = try await model.createGuardian(
                        displayName: displayName,
                        email: email,
                        phone: phone
                    )
                    isSaving = false
                }
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailIsValid: Bool {
        GuardianContact.normalizedEmail(trimmedEmail) != nil
    }

    private var phoneIsValid: Bool {
        GuardianContact.formattedUSPhone(trimmedPhone) != nil
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && emailIsValid
            && phoneIsValid
    }
}

@MainActor
struct LearnerEditorView: View {
    let model: AppModel
    let original: Student?

    @State private var guardianID: GuardianID
    @State private var displayName: String
    @State private var legalName: String
    @State private var kind: StudentKind
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, guardianID: GuardianID, student: Student? = nil) {
        self.model = model
        original = student
        _guardianID = State(initialValue: student?.guardianID ?? guardianID)
        _displayName = State(initialValue: student?.displayName ?? "")
        _legalName = State(initialValue: student?.legalName ?? "")
        _kind = State(initialValue: student?.kind ?? .child)
        _isActive = State(initialValue: student?.isActive ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: original == nil ? "添加学员档案" : "编辑学员档案")

            TextField("常用姓名", text: $displayName)
            TextField("法定姓名（选填）", text: $legalName)
            Picker("所属监护人", selection: $guardianID) {
                ForEach(model.guardians) { guardian in
                    Text(guardian.displayName).tag(guardian.id)
                }
            }
            Picker("类型", selection: $kind) {
                Text("少儿").tag(StudentKind.child)
                Text("成人本人").tag(StudentKind.adult)
            }
            .pickerStyle(.segmented)
            Toggle("启用档案", isOn: $isActive)

            if let errorMessage {
                Text(errorMessage)
                    .font(MDType.compact)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(original == nil ? "添加" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSaving
                    )
            }
        }
        .padding(20)
        .frame(width: 430)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                if var student = original {
                    student.guardianID = guardianID
                    student.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    student.legalName = legalName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .nilIfEmpty
                    student.kind = kind
                    student.isActive = isActive
                    try await model.saveStudent(student)
                } else {
                    try await model.createStudent(
                        displayName: displayName,
                        legalName: legalName,
                        kind: kind,
                        guardianID: guardianID
                    )
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct GuardianLinkCodeSheet: View {
    let code: GuardianLinkCode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GuardianLinkCodeContent(code: code) {
            dismiss()
        }
        .padding(20)
        .frame(width: 480)
    }
}

private struct GuardianLinkCodeContent: View {
    let code: GuardianLinkCode
    let onDone: () -> Void

    @State private var didCopy = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "监护人码", english: "LINK CODE")

            HStack(spacing: 10) {
                Text(code.code)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    copyCode()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("复制监护人码")
            }
            .padding(14)
            .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))

            Label(
                "有效至 \(code.expiresAt.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "clock"
            )
            .font(MDType.compact)
            .foregroundStyle(theme.secondaryText)

            Label("此完整号码仅显示一次", systemImage: "lock")
                .font(MDType.compactStrong)
                .foregroundStyle(theme.warning)

            HStack {
                Spacer()
                Button("完成", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.code, forType: .string)
        didCopy = true
    }
}
#endif
