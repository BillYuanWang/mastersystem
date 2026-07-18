#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

@MainActor
struct GuardianEditorView: View {
    let model: AppModel

    @State private var displayName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var issuedCode: GuardianLinkCode?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let issuedCode {
                GuardianLinkCodeContent(code: issuedCode) {
                    dismiss()
                }
            } else {
                form
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加监护人", english: "NEW FAMILY")

            Form {
                TextField("监护人姓名", text: $displayName)
                TextField("邮箱（选填）", text: $email)
                TextField("电话（选填）", text: $phone)
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
                Button("创建") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSaving
                    )
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                issuedCode = try await model.createGuardian(
                    displayName: displayName,
                    email: email,
                    phone: phone
                )
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

@MainActor
struct LearnerEditorView: View {
    let model: AppModel
    let guardianID: GuardianID

    @State private var displayName = ""
    @State private var legalName = ""
    @State private var kind = StudentKind.child
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加学员档案", english: "NEW LEARNER")

            TextField("常用姓名", text: $displayName)
            TextField("法定姓名（选填）", text: $legalName)
            Picker("类型", selection: $kind) {
                Text("少儿").tag(StudentKind.child)
                Text("成人本人").tag(StudentKind.adult)
            }
            .pickerStyle(.segmented)

            if let errorMessage {
                Text(errorMessage)
                    .font(MDType.compact)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
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
                try await model.createStudent(
                    displayName: displayName,
                    legalName: legalName,
                    kind: kind,
                    guardianID: guardianID
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
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
