import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceMobileApp: App {
    private let repository = PreviewMasterDanceStore.sample()
    @AppStorage("previewRole") private var roleRawValue = AppRole.guardian.rawValue

    var body: some Scene {
        WindowGroup {
            AppShell(
                role: AppRole(rawValue: roleRawValue) ?? .guardian,
                repository: repository
            )
        }
    }
}
