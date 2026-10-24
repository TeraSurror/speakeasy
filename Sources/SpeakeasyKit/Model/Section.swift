import CoreGraphics

public enum Section: String, Codable, CaseIterable, Sendable {
    case visible, hidden, alwaysHidden
}

public struct MenuBarItem: Identifiable, Equatable, Sendable {
    /// Bundle ID (or app name) plus left-to-right index within that app.
    public var id: String
    public var appName: String
    public var bundleID: String?
    public var pid: Int32
    public var windowID: UInt32
    /// Global coordinates, origin top-left of the primary display (CoreGraphics space).
    public var frame: CGRect
    public var section: Section

    public init(
        id: String, appName: String, bundleID: String? = nil, pid: Int32 = 0,
        windowID: UInt32 = 0, frame: CGRect, section: Section = .visible
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.pid = pid
        self.windowID = windowID
        self.frame = frame
        self.section = section
    }
}

public struct ToggleAppearance: Equatable, Sendable {
    public var icon: ToggleIcon
    public var isHidden: Bool
    public var showSeparator: Bool
    public var hasBadge: Bool
    /// Slide the items in and out instead of switching instantly.
    public var animates: Bool

    public init(icon: ToggleIcon, isHidden: Bool, showSeparator: Bool, hasBadge: Bool = false, animates: Bool = true) {
        self.icon = icon
        self.isHidden = isHidden
        self.showSeparator = showSeparator
        self.hasBadge = hasBadge
        self.animates = animates
    }
}

public struct KeyCombo: Equatable, Sendable {
    public var keyCode: Int
    /// Carbon modifier mask (cmdKey | shiftKey | optionKey | controlKey).
    public var carbonModifiers: Int

    public init(keyCode: Int, carbonModifiers: Int) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }
}

public struct ScreenInfo: Equatable, Sendable {
    /// Frame in CoreGraphics global space (origin top-left of the primary display).
    public var cgFrame: CGRect
    public var auxiliaryLeftWidth: CGFloat?
    public var auxiliaryRightWidth: CGFloat?
    /// `safeAreaInsets.top`; non-zero only on displays with a notch.
    public var topInset: CGFloat

    public init(cgFrame: CGRect, auxiliaryLeftWidth: CGFloat? = nil, auxiliaryRightWidth: CGFloat? = nil, topInset: CGFloat = 0) {
        self.cgFrame = cgFrame
        self.auxiliaryLeftWidth = auxiliaryLeftWidth
        self.auxiliaryRightWidth = auxiliaryRightWidth
        self.topInset = topInset
    }

    public var notchRect: CGRect? {
        guard topInset > 0, let left = auxiliaryLeftWidth, let right = auxiliaryRightWidth else { return nil }
        let width = cgFrame.width - left - right
        guard width > 0 else { return nil }
        return CGRect(x: cgFrame.minX + left, y: cgFrame.minY, width: width, height: topInset)
    }
}
