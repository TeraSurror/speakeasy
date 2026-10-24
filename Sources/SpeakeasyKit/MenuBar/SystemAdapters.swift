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

/// Lists windows on the status-bar layer and assigns each to an app and a section.
///
/// The window list gives each item's window and frame. Since macOS 26 every status item window is owned by
/// Control Center, so the owning app comes from the Accessibility API, matched to windows by position. An
/// off-screen window nobody claims is a placeholder (Control Center keeps several, some 5000 pt wide) and is dropped.
/// Without Accessibility only on-screen items are returned, attributed to their window owner.
public struct WindowListItemService: MenuBarItemService {
    /// An AX frame is the item's button, inside a slightly larger window, so compare centers.
    static let matchTolerance: CGFloat = 4

    private let windows: WindowListing
    private let extras: ExtrasMenuBarReading
    private let separators: SeparatorLocating?
    private let screens: ScreenProviding

    public init(
        windows: WindowListing = CGWindowListing(), extras: ExtrasMenuBarReading = AXExtrasMenuBarReader(),
        separators: SeparatorLocating? = nil, screens: ScreenProviding = NSScreenProvider()
    ) {
        self.windows = windows
        self.extras = extras
        self.separators = separators
        self.screens = screens
    }

    @MainActor
    public func currentItems() -> [MenuBarItem] {
        let own = separators?.ownWindowIDs ?? []
        let items = Self.items(from: windows.windowInfo(), extras: extras.extrasItems()).filter { !own.contains($0.windowID) }
        guard let frames = separators?.separatorFrames else { return items }
        let others = screens.screens.map(\.cgFrame).filter { !($0.minX <= frames.toggleMidX && frames.toggleMidX < $0.maxX) }
        return SectionClassifier.classify(items, separators: frames, otherScreens: others)
    }

    private struct Entry {
        var name: String
        var label: String?
        var idHint: String?
        var bundleID: String?
        var pid: Int32
        var windowID: UInt32
        var frame: CGRect
    }

    /// Turns raw `CGWindowListCopyWindowInfo` dictionaries into items. Split out so it can be tested.
    static func items(
        from list: [[String: Any]], extras: [ExtrasMenuItem] = [],
        statusLayer: Int = Int(CGWindowLevelForKey(.statusWindow))
    ) -> [MenuBarItem] {
        var unclaimed = extras
        var entries: [Entry] = []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == statusLayer,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let onscreen = (info[kCGWindowIsOnscreen as String] as? Bool) == true

            if let index = unclaimed.firstIndex(where: { abs($0.frame.midX - frame.midX) <= matchTolerance && abs($0.frame.midY - frame.midY) <= frame.height }) {
                let match = unclaimed.remove(at: index)
                entries.append(Entry(
                    name: match.appName, label: match.label, idHint: match.identifier, bundleID: match.bundleID,
                    pid: match.pid, windowID: id, frame: frame))
            } else if onscreen {
                let name = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
                let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
                entries.append(Entry(
                    name: name, label: title, idHint: nil,
                    bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                    pid: pid, windowID: id, frame: frame))
            }
        }
        entries.sort { $0.frame.minX < $1.frame.minX }

        func key(_ entry: Entry) -> String { entry.bundleID ?? entry.name }
        // A stable identifier, or failing that a title, names the item; it only counts if unique within the app.
        func hint(_ entry: Entry) -> String? { entry.idHint ?? entry.label }
        var hintCounts: [String: Int] = [:]
        for entry in entries { hintCounts["\(key(entry))|\(hint(entry) ?? "")", default: 0] += 1 }

        var counts: [String: Int] = [:]
        return entries.map { entry in
            let key = key(entry)
            let index = counts[key, default: 0]
            counts[key] = index + 1
            let unique = hint(entry).map { hintCounts["\(key)|\($0)"] == 1 } ?? false
            let id = unique ? "\(key)|\(hint(entry)!)" : "\(key)#\(index)"
            return MenuBarItem(
                id: id, appName: entry.name, title: entry.label, bundleID: entry.bundleID,
                pid: entry.pid, windowID: entry.windowID, frame: entry.frame)
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
