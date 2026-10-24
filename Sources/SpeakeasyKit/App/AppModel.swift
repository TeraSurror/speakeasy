import SwiftUI

@MainActor
public final class AppModel: ObservableObject {
    @Published public var settings: Settings {
        didSet {
            if settings != oldValue { store.save(settings) }
        }
    }
    @Published public private(set) var launchAtLogin: Bool
    @Published public var launchAtLoginError: String?
    /// Every discovered status item with its section; refreshed on app launch/quit and display changes.
    @Published public var items: [MenuBarItem] = []
    @Published public var notchItems: [MenuBarItem] = []
    @Published public var hotkeyConflict: String?

    var showWelcome: () -> Void = {}
    var diagnostics: () -> String = { "" }

    private let store: SettingsPersisting
    private let loginItems: LoginItemControlling
    private let hotkeys: HotkeyRegistering
    private let conflicts: HotkeyConflictChecking

    public init(
        store: SettingsPersisting, loginItems: LoginItemControlling,
        hotkeys: HotkeyRegistering, conflicts: HotkeyConflictChecking
    ) {
        self.store = store
        self.loginItems = loginItems
        self.hotkeys = hotkeys
        self.conflicts = conflicts
        self.settings = store.load()
        self.launchAtLogin = loginItems.isEnabled
    }

    /// The real system state is the source of truth; the user may change it in System Settings.
    public func refreshLaunchAtLogin() {
        launchAtLogin = loginItems.isEnabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItems.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            Log.general.error("Launch at login failed: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
    }

    public func refreshHotkeyConflict() {
        guard let combo = hotkeys.combo(for: .toggleHiddenSection) else {
            hotkeyConflict = nil
            return
        }
        hotkeyConflict = conflicts.conflict(for: combo)
    }
}
