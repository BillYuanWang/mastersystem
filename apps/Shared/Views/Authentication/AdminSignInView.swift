#if os(macOS)
import SwiftUI

@MainActor
struct AdminSignInView: View {
    let session: AdminSessionModel

    @State private var email = ""
    @State private var password = ""
    @State private var rememberLogin: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(session: AdminSessionModel) {
        self.session = session
        _rememberLogin = State(initialValue: session.defaultRememberLogin)
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MasterDanceLogoView()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MD DESK")
                            .mdFont(.monoStrong)
                            .foregroundStyle(theme.accent)
                        Text("教务登录")
                            .mdFont(.bodyStrong)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                    TextField("name@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(signIn)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                    AdminPasswordField(text: $password, onSubmit: signIn)
                }

                HStack(spacing: 12) {
                    Toggle("记住登录", isOn: $rememberLogin)
                        .toggleStyle(.checkbox)
                        .mdFont(.compactStrong)
                    Spacer()
                    Text("最长 180 天")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }

                if let errorMessage = session.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: signIn) {
                    HStack(spacing: 7) {
                        Image(systemName: session.isWorking ? "ellipsis" : "arrow.right")
                        Text(session.isWorking ? "请稍候" : "登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(session.isWorking)
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            .frame(width: 360)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }

            Spacer()

            Text("MASTER DANCE · 教务专用")
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func signIn() {
        Task {
            await session.signIn(
                email: email,
                password: password,
                rememberLogin: rememberLogin
            )
        }
    }
}

private struct AdminPasswordField: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 6) {
            Group {
                if isPasswordVisible {
                    TextField("密码", text: $text)
                } else {
                    SecureField("密码", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit(onSubmit)

            Button {
                isPasswordVisible.toggle()
                isFocused = true
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.secondaryText)
            .help(isPasswordVisible ? "隐藏密码" : "显示密码")
            .accessibilityLabel(isPasswordVisible ? "隐藏密码" : "显示密码")
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.separator, lineWidth: 1)
        }
    }
}
#endif
