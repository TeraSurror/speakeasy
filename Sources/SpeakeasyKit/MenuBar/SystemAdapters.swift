import AppKit

/// Real implementations of the small system-facing protocols.

public struct DispatchScheduler: Scheduling {
    public init() {}

    @MainActor
    public func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TaskHandle {
        let work = DispatchWorkItem { MainActor.assumeIsolated { action() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
        return TaskHandle { work.cancel() }
    }
}

public struct NSScreenProvider: ScreenProviding {
    public init() {}

    @MainActor
    public var screens: [ScreenInfo] {
        guard let primary = NSScreen.screens.first else { return [] }
        let primaryHeight = primary.frame.height
        return NSScreen.screens.map { screen in
            let f = screen.frame
            let cgFrame = CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
            return ScreenInfo(
                cgFrame: cgFrame,
                auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
                auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
                topInset: screen.safeAreaInsets.top
            )
        }
    }
}

public struct CGWindowListing: WindowListing {
    public init() {}

    public func windowInfo() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    }
}

/// Lists windows on the status-bar layer and assigns each to a section. Frames and owner names need no
/// Screen Recording permission; window titles may be empty without it, in which case identity falls back
/// to the item's left-to-right index within its app.
public struct WindowListItemService: MenuBarItemService {
    /// Real status items are small; wider off-screen windows are placeholders (Control Center keeps some
    /// thousands of points wide).
    static let maxOffscreenItemWidth: CGFloat = 200

    private let windows: WindowListing
    private let separators: SeparatorLocating?
    private let screens: ScreenProviding

    public init(
        windows: WindowListing = CGWindowListing(), separators: SeparatorLocating? = nil,
        screens: ScreenProviding = NSScreenProvider()
    ) {
        self.windows = windows
        self.separators = separators
        self.screens = screens
    }

    @MainActor
    public func currentItems() -> [MenuBarItem] {
        let frames = separators?.separatorFrames
        let own = separators?.ownWindowIDs ?? []
        let items = Self.items(from: windows.windowInfo(), offscreenLimit: frames?.hiddenMinX)
            .filter { !own.contains($0.windowID) }
        guard let frames else { return items }
        let others = screens.screens.map(\.cgFrame).filter { !($0.minX <= frames.toggleMidX && frames.toggleMidX < $0.maxX) }
        return SectionClassifier.classify(items, separators: frames, otherScreens: others)
    }

    /// Turns raw `CGWindowListCopyWindowInfo` dictionaries into items. Split out so it can be tested.
    /// Off-screen windows are kept only when they sit left of `offscreenLimit` (items the separator pushed away).
    static func items(
        from list: [[String: Any]], statusLayer: Int = Int(CGWindowLevelForKey(.statusWindow)),
        offscreenLimit: CGFloat? = nil
    ) -> [MenuBarItem] {
        var raw: [(name: String, title: String?, pid: Int32, id: UInt32, frame: CGRect)] = []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == statusLayer,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let onscreen = (info[kCGWindowIsOnscreen as String] as? Bool) == true
            if !onscreen {
                guard let limit = offscreenLimit, frame.width <= maxOffscreenItemWidth, frame.maxX <= limit + 1 else { continue }
            }
            let name = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
            raw.append((name, title, pid, id, frame))
        }
        raw.sort { $0.frame.minX < $1.frame.minX }

        func key(_ entry: (name: String, title: String?, pid: Int32, id: UInt32, frame: CGRect)) -> String {
            NSRunningApplication(processIdentifier: entry.pid)?.bundleIdentifier ?? entry.name
        }
        var titleCounts: [String: Int] = [:]
        for entry in raw { titleCounts["\(key(entry))|\(entry.title ?? "")", default: 0] += 1 }

        var counts: [String: Int] = [:]
        return raw.map { entry in
            let bundleID = NSRunningApplication(processIdentifier: entry.pid)?.bundleIdentifier
            let key = bundleID ?? entry.name
            let index = counts[key, default: 0]
            counts[key] = index + 1
            // A title identifies the item only if it's unique within the app; otherwise use the index.
            let unique = entry.title.map { titleCounts["\(key)|\($0)"] == 1 } ?? false
            let id = unique ? "\(key)|\(entry.title!)" : "\(key)#\(index)"
            return MenuBarItem(
                id: id, appName: entry.name, title: entry.title, bundleID: bundleID,
                pid: entry.pid, windowID: entry.id, frame: entry.frame
            )
        }
    }
}

public struct PopupMenuDetector: MenuOpenDetecting {
    public init() {}

    @MainActor
    public var isMenuOpen: Bool {
        let popupLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains { ($0[kCGWindowLayer as String] as? Int) == popupLevel }
    }
}
