import SwiftUI

public enum MoveStatus: Equatable {
    case idle
    case moving(String)
    case done(String)
    case failed(String)
}

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

    @Published public var moveStatus: MoveStatus = .idle
    @Published public private(set) var accessibilityTrusted = false

    var mover: ItemMoving?
    var accessibility: AccessibilityPermission? {
        didSet { refreshAccessibility() }
    }
    var iconProvider: (MenuBarItem) -> NSImage? = { _ in nil }
    var refreshItems: () -> Void = {}
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

    // MARK: Layout (F10)

    public func icon(for item: MenuBarItem) -> NSImage? { iconProvider(item) }

    public func refreshAccessibility() {
        let trusted = accessibility?.isTrusted ?? false
        guard trusted != accessibilityTrusted else { return }
        accessibilityTrusted = trusted
        refreshItems() // item ownership comes from Accessibility, so rediscover when it changes
    }

    public func requestAccessibility() {
        accessibility?.requestPrompt()
        refreshAccessibility()
    }

    public func move(itemID: String, to section: Section) {
        Task { await run(moves: [itemID], to: section) }
    }

    public func moveOverflowFromNotch() {
        let ids = notchItems.map(\.id)
        guard !ids.isEmpty else { return }
        Task { await run(moves: ids, to: .hidden) }
    }

    func run(moves ids: [String], to section: Section) async {
        guard let mover else { return }
        if case .moving = moveStatus { return }
        var failures: [String] = []
        var moved = 0
        for id in ids {
            let name = items.first { $0.id == id }?.appName ?? id
            moveStatus = .moving(name)
            switch await mover.move(itemID: id, to: section) {
            case .moved: moved += 1
            case .failed(let failure): failures.append("\(name): \(failure.message)")
            }
        }
        refreshItems()
        if let first = failures.first {
            moveStatus = .failed(failures.count == 1 ? first : "\(failures.count) items couldn't be moved. \(first)")
        } else {
            moveStatus = .done(moved == 1 ? "Moved." : "Moved \(moved) items.")
        }
    }
}
