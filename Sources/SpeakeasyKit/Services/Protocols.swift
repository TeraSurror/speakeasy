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

/// One item from an app's `AXExtrasMenuBar`. On macOS 26 every status item window is owned by Control Center,
/// so this is the only way to learn which app an item belongs to. It also reports items pushed off-screen.
public struct ExtrasMenuItem: Equatable, Sendable {
    public var pid: Int32
    public var appName: String
    public var bundleID: String?
    /// The item's title or description, e.g. "Battery".
    public var label: String?
    /// A stable identifier such as `com.apple.menuextra.battery`, when the app provides one.
    public var identifier: String?
    /// Global coordinates, origin top-left of the primary display.
    public var frame: CGRect

    public init(pid: Int32, appName: String, bundleID: String? = nil, label: String? = nil, identifier: String? = nil, frame: CGRect) {
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.label = label
        self.identifier = identifier
        self.frame = frame
    }
}

public protocol ExtrasMenuBarReading {
    /// Empty when Accessibility hasn't been granted.
    func extrasItems() -> [ExtrasMenuItem]
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

/// Accessibility is needed to post synthetic mouse events (F10). Never prompted for at launch.
public protocol AccessibilityPermission {
    var isTrusted: Bool { get }
    /// Shows the system prompt. Callers explain why first.
    func requestPrompt()
}

public struct SyntheticMouseEvent: Equatable, Sendable {
    public enum Kind: Sendable { case move, down, dragged, up }
    public var kind: Kind
    public var location: CGPoint
    /// Whether ⌘ is held; macOS only lets you rearrange status items with ⌘-drag.
    public var command: Bool

    public init(_ kind: Kind, at location: CGPoint, command: Bool = true) {
        self.kind = kind
        self.location = location
        self.command = command
    }
}

public protocol EventPosting {
    @MainActor var cursorLocation: CGPoint { get }
    @MainActor func post(_ event: SyntheticMouseEvent)
    @MainActor func warpCursor(to location: CGPoint)
}

public enum MoveFailure: Error, Equatable, Sendable {
    case noPermission
    case busy
    case itemNotFound
    case separatorsUnavailable
    /// The item is hidden behind the notch (or otherwise off-screen) so there is nothing to grab.
    case notReachable
    case didNotLand(actual: Section?)

    public var message: String {
        switch self {
        case .noPermission: "Speakeasy needs Accessibility access to move items."
        case .busy: "Another move is still in progress."
        case .itemNotFound: "The item is no longer in the menu bar."
        case .separatorsUnavailable: "Speakeasy's own menu bar items aren't ready yet."
        case .notReachable: "The item is hidden behind the notch and can't be grabbed. Move another item out of the way first."
        case .didNotLand: "macOS didn't accept the move. Try again, or ⌘-drag the item yourself."
        }
    }
}

public enum MoveResult: Equatable, Sendable {
    case moved
    case failed(MoveFailure)
}

public protocol ItemMoving {
    /// Moves the item into `section` with a synthesized ⌘-drag and confirms it landed.
    @MainActor func move(itemID: String, to section: Section) async -> MoveResult
}

/// Temporarily reveals every section so all items can be grabbed, and restores the previous state afterwards.
public protocol LayoutSessionControlling: AnyObject {
    @MainActor func beginLayoutSession()
    @MainActor func endLayoutSession()
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
