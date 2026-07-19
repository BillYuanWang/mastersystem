#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileAuthenticationRootView: View {
    let session: MobileSessionModel
    @Binding var appearanceRawValue: String

    var body: some View {
        Group {
            switch session.phase {
            case .restoring:
                MobileAuthenticationLoadingView()
            case .signedOut:
                MobileSignInAndRegistrationView(session: session)
            case .emailConfirmationRequired(let email):
                MobileEmailConfirmationView(session: session, email: email)
            case .guardianLinkRequired:
                MobileGuardianClaimView(session: session)
            case .ready:
                if let repository = session.repository, let profile = session.profile {
                    AppShell(
                        role: profile.role,
                        repository: repository,
                        appearanceRawValue: $appearanceRawValue,
                        accountDisplayName: profile.displayName,
                        onSignOut: { Task { await session.signOut() } },
                        memberActions: session.memberActions
                    )
                } else {
                    MobileAuthenticationLoadingView()
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            Task { await session.handleAuthCallback(url) }
        }
        .overlay(alignment: .top) {
            MobileSessionNoticeView(
                errorMessage: session.errorMessage,
                noticeMessage: session.noticeMessage,
                dismiss: session.clearMessages
            )
            .padding(.top, 8)
            .padding(.horizontal, 12)
        }
        .overlay {
            CloudSyncOverlay(
                isActive: session.isWorking,
                label: "正在连接"
            )
            .zIndex(100)
        }
        .sheet(isPresented: passwordUpdateBinding) {
            MobilePasswordUpdateView(session: session)
                .interactiveDismissDisabled()
        }
    }

    private var passwordUpdateBinding: Binding<Bool> {
        Binding(
            get: { session.needsPasswordUpdate },
            set: { session.needsPasswordUpdate = $0 }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearanceRawValue) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum MobileAuthenticationMode: String, CaseIterable, Identifiable {
    case signIn
    case register

    var id: String { rawValue }
    var title: String { self == .signIn ? "登录" : "家长注册" }
}

@MainActor
private struct MobileSignInAndRegistrationView: View {
    let session: MobileSessionModel

    @State private var mode = MobileAuthenticationMode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var invitationCode = ""
    @State private var verifiedInvitation: GuardianRegistrationInvitation?
    @State private var showingRegistrationContract = false
    @State private var showingPasswordReset = false
    @Environment(\.colorScheme) private var colorScheme

    init(session: MobileSessionModel) {
        self.session = session
        _email = State(initialValue: session.accountEmail ?? "")
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 34)

                VStack(spacing: 12) {
                    MasterDanceLogoView()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    Text("MASTER DANCE")
                        .mdFont(size: 18, weight: .bold, design: .monospaced)
                        .foregroundStyle(theme.primaryText)
                    Text(mode == .signIn ? "教务与家庭账号" : "使用学校邀请码激活家长账号")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }

                Picker("账号方式", selection: $mode) {
                    ForEach(MobileAuthenticationMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    if mode == .signIn {
                        MobileAuthTextField(
                            title: "邮箱",
                            systemImage: "envelope",
                            text: $email,
                            contentType: .username
                        )

                        MobileAuthSecureField(
                            title: "密码",
                            systemImage: "lock",
                            text: $password,
                            contentType: .password
                        )
                    } else if let invitation = verifiedInvitation {
                        verifiedInvitationView(invitation, theme: theme)
                        Text("下一步阅读并签署学校合同，然后设置登录密码。")
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MobileGuardianInvitationField(text: $invitationCode)
                    }
                }

                Button(action: submit) {
                    Label(
                        session.isWorking ? "请稍候" : submitTitle,
                        systemImage: session.isWorking ? "ellipsis" : submitSystemImage
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(!canSubmit || session.isWorking)

                if mode == .signIn {
                    Button("忘记密码？") {
                        showingPasswordReset = true
                    }
                    .buttonStyle(.plain)
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.accent)
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .sheet(isPresented: $showingPasswordReset) {
            MobilePasswordResetRequestView(session: session, initialEmail: email)
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingRegistrationContract) {
            if let invitation = verifiedInvitation {
                MobileGuardianContractRegistrationView(
                    session: session,
                    invitation: invitation,
                    onCancel: { showingRegistrationContract = false },
                    onCompleted: { showingRegistrationContract = false }
                )
            }
        }
        .onChange(of: mode) {
            password = ""
            invitationCode = ""
            verifiedInvitation = nil
            showingRegistrationContract = false
            session.clearMessages()
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .signIn:
            return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
        case .register:
            guard verifiedInvitation != nil else {
                return !invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
    }

    private var submitTitle: String {
        if mode == .signIn { return "登录" }
        return verifiedInvitation == nil ? "验证邀请码" : "阅读合同并注册"
    }

    private var submitSystemImage: String {
        if mode == .signIn { return "arrow.right.circle.fill" }
        return verifiedInvitation == nil ? "checkmark.shield.fill" : "doc.text.magnifyingglass"
    }

    private func submit() {
        Task {
            if mode == .signIn {
                await session.signIn(email: email, password: password)
            } else if verifiedInvitation != nil {
                showingRegistrationContract = true
            } else {
                let invitation = await session.previewGuardianRegistration(invitationCode)
                verifiedInvitation = invitation
                showingRegistrationContract = invitation != nil
            }
        }
    }

    private func verifiedInvitationView(
        _ invitation: GuardianRegistrationInvitation,
        theme: MDTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(theme.success)
                Text("已验证·\(invitation.guardianName)")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button("更换") {
                    invitationCode = ""
                    verifiedInvitation = nil
                    showingRegistrationContract = false
                }
                .buttonStyle(.plain)
                .mdFont(.compactStrong)
                .foregroundStyle(theme.accent)
            }

            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录邮箱")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                    Text(invitation.email)
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }
        }
    }
}

private struct MobileEmailConfirmationView: View {
    let session: MobileSessionModel
    let email: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 18) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(theme.accent)
            Text("确认邮箱")
                .mdFont(size: 20, weight: .bold)
            Text("确认邮件已经发送到\n\(email)")
                .mdFont(.body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Text("从邮件中的链接完成确认。返回登录后，家庭会自动连接，无需再次输入邀请码。")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
            Button("已经确认，返回登录") {
                Task { await session.continueAfterEmailConfirmation() }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

@MainActor
private struct MobileGuardianClaimView: View {
    let session: MobileSessionModel
    @State private var code = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 20) {
            Spacer()
            MasterDanceLogoView()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            Text("连接你的家庭")
                .mdFont(size: 20, weight: .bold)
            Text("向教务老师获取一次性家长邀请码。连接后即可看到这个家庭下的所有学员。")
                .mdFont(.body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)

            TextField("MD ···· ···· ···· ···· ····", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .mdFont(size: 15, weight: .semibold, design: .monospaced)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }

            Button {
                Task { await session.claimGuardianCode(code) }
            } label: {
                Label("连接家庭", systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("换一个账号") {
                Task { await session.signOut() }
            }
            .buttonStyle(.plain)
            .mdFont(.compactStrong)
            .foregroundStyle(theme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

@MainActor
private struct MobilePasswordResetRequestView: View {
    let session: MobileSessionModel
    @State private var email: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(session: MobileSessionModel, initialEmail: String) {
        self.session = session
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            VStack(spacing: 18) {
                Text("输入注册邮箱。点击邮件中的链接后会返回 App，再输入两次新密码。")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MobileAuthTextField(
                    title: "邮箱",
                    systemImage: "envelope",
                    text: $email,
                    contentType: .emailAddress
                )
                Button("发送重设邮件") {
                    Task {
                        if await session.sendPasswordReset(email: email) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
            }
            .padding(20)
            .background(theme.background)
            .navigationTitle("重设密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

@MainActor
private struct MobilePasswordUpdateView: View {
    let session: MobileSessionModel
    @State private var password = ""
    @State private var confirmation = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            VStack(spacing: 14) {
                MobileAuthSecureField(
                    title: "新密码",
                    systemImage: "lock",
                    text: $password,
                    contentType: .newPassword
                )
                MobileAuthSecureField(
                    title: "再次输入新密码",
                    systemImage: "lock.rotation",
                    text: $confirmation,
                    contentType: .newPassword
                )
                Text("至少 10 位，同时包含字母和数字")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("更新密码") {
                    Task {
                        if await session.updatePassword(password, confirmation: confirmation) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
            }
            .padding(20)
            .background(theme.background)
            .navigationTitle("设置新密码")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MobileGuardianInvitationField: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(theme.secondaryText)
                .frame(width: 20)
            TextField("MD-····-····-····-····-····", text: $text)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .mdFont(size: 14, weight: .semibold, design: .monospaced)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
    }
}

private struct MobileAuthTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let contentType: UITextContentType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 20)
            TextField(title, text: $text)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(contentType)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
    }
}

struct MobileAuthSecureField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let contentType: UITextContentType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 20)
            SecureField(title, text: $text)
                .textContentType(contentType)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
    }
}

private struct MobileSessionNoticeView: View {
    let errorMessage: String?
    let noticeMessage: String?
    let dismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let message = errorMessage ?? noticeMessage {
            let theme = MDTheme(scheme: colorScheme)
            HStack(spacing: 9) {
                Image(systemName: errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(message)
                    .mdFont(.compactStrong)
                    .lineLimit(3)
                Spacer(minLength: 4)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(errorMessage == nil ? theme.primaryText : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                errorMessage == nil ? theme.raisedSurface : theme.danger,
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .overlay {
                if errorMessage == nil {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct MobileAuthenticationLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 16) {
            MasterDanceLogoView()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
            ProgressView()
                .controlSize(.small)
            Text("MASTER DANCE")
                .mdFont(.monoStrong)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
#endif
