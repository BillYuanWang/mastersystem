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
    @State private var address: String

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, guardian: Guardian? = nil) {
        self.model = model
        original = guardian
        _displayName = State(initialValue: guardian?.displayName ?? "")
        _email = State(initialValue: guardian?.email ?? "")
        let storedPhone = guardian?.phone ?? ""
        _phone = State(initialValue: GuardianContact.formattedUSPhone(storedPhone) ?? storedPhone)
        _address = State(initialValue: guardian?.address ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: original == nil ? "添加监护人" : "编辑监护人")

            Form {
                LabeledContent("监护人姓名（必填）") {
                    TextField("姓名", text: $displayName)
                        .frame(minWidth: 360)
                }
                LabeledContent("邮箱（必填）") {
                    TextField("name@example.com", text: $email)
                        .frame(minWidth: 360)
                }
                if !trimmedEmail.isEmpty, !emailIsValid {
                    Text("邮箱格式不正确。")
                        .mdFont(.compact)
                        .foregroundStyle(.red)
                }
                LabeledContent("电话（必填）") {
                    TextField("+1 (000) 000-0000", text: $phone)
                        .mdFont(.mono)
                        .frame(minWidth: 360)
                }
                if !trimmedPhone.isEmpty, !phoneIsValid {
                    Text("请输入 10 位美国电话号码。")
                        .mdFont(.compact)
                        .foregroundStyle(.red)
                }
                LabeledContent("家庭住址（选填）") {
                    TextField("街道、城市、州、邮编", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                        .frame(minWidth: 360)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(original == nil ? "创建" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 660)
    }

    private func save() {
        if var guardian = original {
            guardian.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guardian.email = email
            guardian.phone = phone
            guardian.address = address
            model.performBackgroundOperation(
                label: "更新监护人",
                successMessage: "监护人资料已更新"
            ) {
                try await model.saveGuardian(guardian)
            }
        } else {
            let nameSnapshot = displayName
            let emailSnapshot = email
            let phoneSnapshot = phone
            let addressSnapshot = address
            model.performBackgroundOperation(
                label: "创建监护人",
                successMessage: "监护人已创建"
            ) {
                let code = try await model.createGuardian(
                    displayName: nameSnapshot,
                    email: emailSnapshot,
                    phone: phoneSnapshot,
                    address: addressSnapshot
                )
                model.retainGuardianLinkCode(code)
            }
        }
        dismiss()
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
    @State private var recordsBirthDate: Bool
    @State private var birthDate: Date
    @State private var kind: StudentKind
    @State private var isActive: Bool

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, guardianID: GuardianID, student: Student? = nil) {
        self.model = model
        original = student
        _guardianID = State(initialValue: student?.guardianID ?? guardianID)
        _displayName = State(initialValue: student?.displayName ?? "")
        _legalName = State(initialValue: student?.legalName ?? "")
        _recordsBirthDate = State(initialValue: student?.birthDate != nil)
        _birthDate = State(initialValue: student?.birthDate ?? Date())
        _kind = State(initialValue: student?.kind ?? .child)
        _isActive = State(initialValue: student?.isActive ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: original == nil ? "添加学员档案" : "编辑学员档案")

            Form {
                LabeledContent("常用姓名（必填）") {
                    TextField("学员常用姓名", text: $displayName)
                        .frame(minWidth: 340)
                }
                LabeledContent("法定姓名（选填）") {
                    TextField("证件姓名", text: $legalName)
                        .frame(minWidth: 340)
                }
                LabeledContent("生日（选填）") {
                    HStack(spacing: 12) {
                        Toggle("记录生日", isOn: $recordsBirthDate)
                            .toggleStyle(.checkbox)
                        if recordsBirthDate {
                            DatePicker(
                                "生日",
                                selection: $birthDate,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                    }
                    .frame(minWidth: 340, alignment: .leading)
                }
                LabeledContent("所属监护人") {
                    Picker("所属监护人", selection: $guardianID) {
                        ForEach(model.guardians) { guardian in
                            Text(guardian.displayName).tag(guardian.id)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 340)
                }
                LabeledContent("学员类型") {
                    Picker("类型", selection: $kind) {
                        Text("少儿").tag(StudentKind.child)
                        Text("成人本人").tag(StudentKind.adult)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 340)
                }
                LabeledContent("档案状态") {
                    Toggle("启用档案", isOn: $isActive)
                        .frame(minWidth: 340, alignment: .leading)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(original == nil ? "添加" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 640)
    }

    private func save() {
        if var student = original {
            student.guardianID = guardianID
            student.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            student.legalName = legalName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            student.birthDate = recordsBirthDate ? birthDate : nil
            student.kind = kind
            student.isActive = isActive
            model.performBackgroundOperation(
                label: "更新学员档案",
                successMessage: "学员档案已更新"
            ) {
                try await model.saveStudent(student)
            }
        } else {
            let nameSnapshot = displayName
            let legalNameSnapshot = legalName
            let birthDateSnapshot = recordsBirthDate ? birthDate : nil
            let kindSnapshot = kind
            let guardianIDSnapshot = guardianID
            model.performBackgroundOperation(
                label: "创建学员档案",
                successMessage: "学员档案已创建"
            ) {
                try await model.createStudent(
                    displayName: nameSnapshot,
                    legalName: legalNameSnapshot,
                    birthDate: birthDateSnapshot,
                    kind: kindSnapshot,
                    guardianID: guardianIDSnapshot
                )
            }
        }
        dismiss()
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
            MDSectionTitle(chinese: "家长邀请码", english: "INVITATION")

            HStack(spacing: 10) {
                Text(code.code)
                    .mdFont(size: 18, weight: .semibold, design: .monospaced)
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
            .mdFont(.compact)
            .foregroundStyle(theme.secondaryText)

            Label("此完整号码仅显示一次", systemImage: "lock")
                .mdFont(.compactStrong)
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
