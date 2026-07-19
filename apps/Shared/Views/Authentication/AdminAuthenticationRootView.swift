#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct AdminAuthenticationRootView: View {
    let session: AdminSessionModel

    @AppStorage("appearancePreference") private var appearanceRawValue = AppearancePreference.system.rawValue
    @State private var isShowingAccount = false

    var body: some View {
        Group {
            switch session.phase {
            case .restoring:
                AdminAuthenticationLoadingView()
            case .signedOut:
                AdminSignInView(session: session)
            case .activationRequired:
                FirstAdministratorActivationView(session: session)
            case .ready:
                if let repository = session.repository, let profile = session.profile {
                    AppShell(
                        role: .administrator,
                        repository: repository,
                        appearanceRawValue: $appearanceRawValue,
                        accountDisplayName: profile.displayName,
                        onManageAccount: { isShowingAccount = true },
                        onSignOut: { Task { await session.signOut() } }
                    )
                    .sheet(isPresented: $isShowingAccount) {
                        AdministratorAccountSheet(session: session)
                    }
                    .sheet(isPresented: passwordSetupBinding) {
                        InvitedAdministratorPasswordView(session: session)
                            .interactiveDismissDisabled()
                    }
                } else {
                    AdminAuthenticationLoadingView()
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            Task { await session.handleAuthCallback(url) }
        }
        .overlay {
            if session.isWorking {
                CloudSyncLoader(label: "正在连接云端")
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.16), value: session.isWorking)
    }

    private var passwordSetupBinding: Binding<Bool> {
        Binding(
            get: { session.needsPasswordSetup },
            set: { session.needsPasswordSetup = $0 }
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

private struct AdminAuthenticationLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 16) {
            MasterDanceLogoView()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            ProgressView()
                .controlSize(.small)
            Text("MD DESK")
                .mdFont(.monoStrong)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
#endif
