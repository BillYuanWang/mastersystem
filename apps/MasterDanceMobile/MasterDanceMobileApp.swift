import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceMobileApp: App {
    private let repository = PreviewMasterDanceStore.sample()
    @AppStorage("previewRole") private var roleRawValue = AppRole.guardian.rawValue
    @AppStorage("appearancePreference") private var appearanceRawValue = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppShell(
                role: AppRole(rawValue: roleRawValue) ?? .guardian,
                repository: repository,
                appearanceRawValue: $appearanceRawValue
            )
            .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearanceRawValue) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
