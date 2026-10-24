import Foundation

public final class TaskHandle: @unchecked Sendable {
    private let onCancel: () -> Void
    public private(set) var isCancelled = false

    public init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }
}

public protocol Scheduling {
    @discardableResult
    @MainActor func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TaskHandle
}

public protocol MenuOpenDetecting {
    /// True while any popup menu is on screen (e.g. from a revealed status item).
    @MainActor var isMenuOpen: Bool { get }
}

/// Enumerates status item windows. M2 grows this into full discovery (F9).
public protocol MenuBarItemService {
    func currentItems() -> [MenuBarItem]
}

public protocol ScreenProviding {
    @MainActor var screens: [ScreenInfo] { get }
}

public protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public enum HotkeyAction: Sendable {
    case toggleHiddenSection
}

public protocol HotkeyRegistering {
    @MainActor func setHandler(for action: HotkeyAction, _ handler: @escaping @MainActor () -> Void)
    @MainActor func combo(for action: HotkeyAction) -> KeyCombo?
}

public protocol HotkeyConflictChecking {
    /// A human-readable description of the conflict, or nil if the combo is free.
    func conflict(for combo: KeyCombo) -> String?
}

public protocol SettingsPersisting {
    func load() -> Settings
    func save(_ settings: Settings)
}

/// Everything AppKit-specific about Speakeasy's two status items. Only `MenuBar/` implements this.
@MainActor
public protocol StatusItemHosting: AnyObject {
    func render(_ appearance: ToggleAppearance)
    /// False when the user has ⌘-dragged the toggle to the left of the separator,
    /// in which case expanding the separator would hide the toggle itself.
    var toggleIsRightOfSeparator: Bool { get }
}
