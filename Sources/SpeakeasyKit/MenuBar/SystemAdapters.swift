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

/// Lists windows on the status-bar layer. Frames and owner names need no Screen Recording permission.
public struct WindowListItemService: MenuBarItemService {
    public init() {}

    public func currentItems() -> [MenuBarItem] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return Self.items(from: list)
    }

    /// Turns raw `CGWindowListCopyWindowInfo` dictionaries into items. Split out so it can be tested.
    static func items(from list: [[String: Any]], statusLayer: Int = Int(CGWindowLevelForKey(.statusWindow))) -> [MenuBarItem] {
        var raw: [(name: String, pid: Int32, id: UInt32, frame: CGRect)] = []
        for info in list {
            // Off-screen status windows are placeholders (Control Center keeps some thousands of points wide).
            guard (info[kCGWindowLayer as String] as? Int) == statusLayer,
                  (info[kCGWindowIsOnscreen as String] as? Bool) == true,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let name = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            raw.append((name, pid, id, frame))
        }
        raw.sort { $0.frame.minX < $1.frame.minX }

        var counts: [String: Int] = [:]
        return raw.map { entry in
            let bundleID = NSRunningApplication(processIdentifier: entry.pid)?.bundleIdentifier
            let key = bundleID ?? entry.name
            let index = counts[key, default: 0]
            counts[key] = index + 1
            return MenuBarItem(
                id: "\(key)#\(index)", appName: entry.name, bundleID: bundleID,
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
