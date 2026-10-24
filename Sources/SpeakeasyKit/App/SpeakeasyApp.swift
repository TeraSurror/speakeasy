import AppKit

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let controller = AppController()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            NSApp.mainMenu = Self.makeMainMenu()
            AppEnvironment.shared.controller.start()
        }
    }

    /// An agent app shows no menu bar of its own, but its windows still need the standard key equivalents
    /// (copy, paste, select all, close, quit) to work, and those come from the main menu.
    @MainActor
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Speakeasy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = window
        main.addItem(windowItem)

        return main
    }
}

/// Starts Speakeasy without SwiftUI's `App` lifecycle. That lifecycle requires a scene, and the only scene that
/// doesn't open a window at launch (`Settings`) shows an empty "Speakeasy Settings" window of its own when triggered.
/// Settings and the welcome guide are plain windows owned by `WindowPresenter`.
public enum SpeakeasyLauncher {
    @MainActor private static let delegate = AppDelegate()

    @MainActor
    public static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // matches LSUIElement
        app.delegate = delegate
        app.run()
    }
}
