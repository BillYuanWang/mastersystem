import AppKit
import MasterDanceCore
import SwiftUI

@main
@MainActor
struct MasterDanceAdminApp: App {
    @NSApplicationDelegateAdaptor(MasterDanceAdminDelegate.self) private var appDelegate
    @State private var session = AdminSessionModel()
    @AppStorage(MDInterfaceFontScale.storageKey) private var interfaceFontScale = MDInterfaceFontScale.defaultValue

    var body: some Scene {
        WindowGroup("MD Desk") {
            AdminAuthenticationRootView(session: session)
                .mdInterfaceFontScale(interfaceFontScale)
                .frame(minWidth: minimumWindowWidth, minHeight: minimumWindowHeight)
                .task { await session.restore() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            InterfaceFontCommands(scale: $interfaceFontScale)
        }
    }

    private var minimumWindowWidth: CGFloat {
        1120 + CGFloat(max(0, MDInterfaceFontScale.normalized(interfaceFontScale) - 1)) * 500
    }

    private var minimumWindowHeight: CGFloat {
        700 + CGFloat(max(0, MDInterfaceFontScale.normalized(interfaceFontScale) - 1)) * 300
    }
}

private struct InterfaceFontCommands: Commands {
    @Binding var scale: Double

    var body: some Commands {
        CommandGroup(replacing: .toolbar) {
            Button("Font Bigger") {
                scale = MDInterfaceFontScale.larger(than: scale)
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(MDInterfaceFontScale.normalized(scale) >= MDInterfaceFontScale.maximum)

            Button("Font Smaller") {
                scale = MDInterfaceFontScale.smaller(than: scale)
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(MDInterfaceFontScale.normalized(scale) <= MDInterfaceFontScale.minimum)

            Button("Font Default") {
                scale = MDInterfaceFontScale.defaultValue
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(MDInterfaceFontScale.normalized(scale) == MDInterfaceFontScale.defaultValue)
        }
    }
}

@MainActor
private final class MasterDanceAdminDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.removeUnusedWindowChromeCommands()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        removeUnusedWindowChromeCommands()
    }

    private func removeUnusedWindowChromeCommands() {
        guard let mainMenu = NSApp.mainMenu else { return }
        pruneWindowChromeCommands(from: mainMenu)
    }

    private func pruneWindowChromeCommands(from menu: NSMenu) {
        for item in menu.items.reversed() {
            if let submenu = item.submenu {
                pruneWindowChromeCommands(from: submenu)
            }
            guard let action = item.action else { continue }
            if hiddenWindowChromeActions.contains(NSStringFromSelector(action)) {
                menu.removeItem(item)
            }
        }
    }

    private var hiddenWindowChromeActions: Set<String> {
        [
            #selector(NSWindow.toggleToolbarShown(_:)),
            #selector(NSWindow.runToolbarCustomizationPalette(_:)),
            #selector(NSWindow.selectNextTab(_:)),
            #selector(NSWindow.selectPreviousTab(_:)),
            #selector(NSWindow.moveTabToNewWindow(_:)),
            #selector(NSWindow.mergeAllWindows(_:)),
            #selector(NSWindow.toggleTabBar(_:)),
            #selector(NSWindow.toggleTabOverview(_:)),
        ].map(NSStringFromSelector).reduce(into: Set<String>()) { $0.insert($1) }
    }
}
