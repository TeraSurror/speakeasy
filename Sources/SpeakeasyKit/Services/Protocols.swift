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

/// Discovers every status item, including ones currently pushed off-screen, with its section (F9).
public protocol MenuBarItemService {
    @MainActor func currentItems() -> [MenuBarItem]
}

/// Raw `CGWindowListCopyWindowInfo` dictionaries for all windows.
public protocol WindowListing {
    func windowInfo() -> [[String: Any]]
}

/// Where Speakeasy's own status items are, so other items can be assigned to sections.
@MainActor
public protocol SeparatorLocating: AnyObject {
    /// Nil until the separators have been laid out.
    var separatorFrames: SeparatorFrames? { get }
    /// Window IDs of Speakeasy's own status items, excluded from discovery.
    var ownWindowIDs: Set<UInt32> { get }
}

/// Reports that the set of status items may have changed (app launch/quit, display change).
/// Changes are debounced; consumers re-read items in response and never poll.
public protocol ItemChangeObserving: AnyObject {
    @MainActor var onChange: (() -> Void)? { get set }
    @MainActor func start()
    @MainActor func stop()
}

public protocol ScreenProviding {
    @MainActor var screens: [ScreenInfo] { get }
}

/// Reports the global pointer position (CoreGraphics space, origin top-left of the primary display).
/// Only running while someone needs it, so it costs nothing otherwise.
public protocol PointerMonitoring: AnyObject {
    @MainActor var onMove: ((CGPoint) -> Void)? { get set }
    @MainActor func start()
    @MainActor func stop()
}

public protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public enum HotkeyAction: Sendable {
    case toggleHiddenSection
    case toggleAlwaysHidden
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
