#if os(macOS)
import SwiftUI

@MainActor
struct AdministratorAccountSheet: View {
    let session: AdminSessionModel

    @State private var email = ""
    @State private var displayName = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: "教务账号", english: "ADMIN ACCOUNTS")
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("关闭")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前教务")
                        .mdFont(.bodyStrong)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(session.administrators) { administrator in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(administrator.isActive ? theme.success : theme.secondaryText)
                                        .frame(width: 7, height: 7)
                                    Text(administrator.displayName)
                                        .mdFont(.bodyStrong)
                                    if administrator.userID == session.profile?.userID {
                                        Text("当前")
                                            .mdFont(.compact)
                                            .foregroundStyle(theme.accent)
                                    }
                                    Spacer()
                                }
                                .frame(height: 38)
                                Divider()
                            }
                        }
                    }
                }
                .padding(16)
                .frame(width: 280)
                .frame(maxHeight: .infinity, alignment: .top)

                Rectangle().fill(theme.separator).frame(width: 1)

                VStack(alignment: .leading, spacing: 14) {
                    Text("邀请新教务")
                        .mdFont(.bodyStrong)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("姓名")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.secondaryText)
                        TextField("教务姓名", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("邮箱")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.secondaryText)
                        TextField("name@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(invite)
                    }

                    if let noticeMessage = session.noticeMessage {
                        Label(noticeMessage, systemImage: "checkmark.circle.fill")
                            .mdFont(.compact)
                            .foregroundStyle(theme.success)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage = session.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .mdFont(.compact)
                            .foregroundStyle(theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button(action: invite) {
                        HStack {
                            if session.isWorking {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("发送邀请")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(session.isWorking)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 680, height: 430)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .task {
            session.clearMessages()
            await session.loadAdministrators()
        }
    }

    private func invite() {
        Task {
            let didInvite = await session.inviteAdministrator(
                email: email,
                displayName: displayName
            )
            if didInvite {
                email = ""
                displayName = ""
            }
        }
    }
}
#endif
