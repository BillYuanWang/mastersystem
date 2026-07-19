#if os(macOS)
import SwiftUI

@MainActor
struct InvitedAdministratorPasswordView: View {
    let session: AdminSessionModel

    @State private var password = ""
    @State private var confirmation = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 18) {
            Label("设置登录密码", systemImage: "key.fill")
                .mdFont(.bodyStrong)
                .foregroundStyle(theme.accent)

            SecureField("新密码", text: $password)
                .textFieldStyle(.roundedBorder)
            SecureField("再次输入", text: $confirmation)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            Text("至少 10 位，同时包含字母和数字")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)

            if let errorMessage = session.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: save) {
                Label("保存密码", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(session.isWorking)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 360)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func save() {
        Task {
            await session.setInvitedAdministratorPassword(password, confirmation: confirmation)
        }
    }
}
#endif
