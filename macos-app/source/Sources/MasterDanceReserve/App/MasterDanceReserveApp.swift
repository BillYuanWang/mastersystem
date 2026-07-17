import AppKit
import SwiftUI

@main
struct MasterDanceReserveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("MD Desk") {
            ContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
