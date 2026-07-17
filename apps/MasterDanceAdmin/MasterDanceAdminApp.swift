import MasterDanceCore
import SwiftUI

@main
struct MasterDanceAdminApp: App {
    private let repository = PreviewMasterDanceStore.sample()

    var body: some Scene {
        WindowGroup("MD Desk") {
            AppShell(role: .administrator, repository: repository)
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}
