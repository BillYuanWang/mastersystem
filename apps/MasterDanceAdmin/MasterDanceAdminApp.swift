import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceAdminApp: App {
    private let repository = PreviewMasterDanceStore.sample()

    var body: some Scene {
        WindowGroup("MD Desk") {
            AppShell(role: .administrator, repository: repository)
                .frame(minWidth: 1120, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
    }
}
