import Foundation
import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceMobileApp: App {
    @State private var session = MobileSessionModel()
    @AppStorage("appearancePreference") private var appearanceRawValue = AppearancePreference.system.rawValue

#if DEBUG
    private let previewRepository = PreviewMasterDanceStore.sample()
#endif

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let role = previewRole {
            AppShell(
                role: role,
                repository: previewRepository,
                appearanceRawValue: $appearanceRawValue,
                accountDisplayName: role == .administrator ? "教务预览" : "家长预览",
                memberActions: role == .administrator ? nil : previewMemberActions
            )
        } else {
            authenticationRoot
        }
#else
        authenticationRoot
#endif
    }

    private var authenticationRoot: some View {
        MobileAuthenticationRootView(
            session: session,
            appearanceRawValue: $appearanceRawValue
        )
        .task { await session.restore() }
    }

#if DEBUG
    private var previewRole: AppRole? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--md-preview-admin") { return .administrator }
        if arguments.contains("--md-preview-guardian") { return .guardian }
        return nil
    }

    private var previewMemberActions: MobileMemberActionService {
        let configuration = SupabaseConfiguration(
            url: URL(string: "http://127.0.0.1:9")!,
            publishableKey: "preview-only"
        )
        return MobileMemberActionService(client: configuration.makeClient())
    }
#endif
}
