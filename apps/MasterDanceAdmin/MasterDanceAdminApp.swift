import AppKit
import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceAdminApp: App {
    @NSApplicationDelegateAdaptor(MasterDanceAdminDelegate.self) private var appDelegate
    @State private var session = AdminSessionModel()

    var body: some Scene {
        WindowGroup("MD Desk") {
            AdminAuthenticationRootView(session: session)
                .frame(minWidth: 1120, minHeight: 700)
                .task { await session.restore() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
    }
}

private final class MasterDanceAdminDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
