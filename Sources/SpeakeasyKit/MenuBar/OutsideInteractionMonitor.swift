import AppKit

/// While running, reports clicks outside the menu bar and app switches. Only active while the
/// hidden section is shown, so it costs nothing when idle.
@MainActor
public final class OutsideInteractionMonitor {
    private var mouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var lastMenuBarClick = Date.distantPast
    private var onOutside: (() -> Void)?

    public init() {}

    public func start(onOutside: @escaping () -> Void) {
        stop()
        self.onOutside = onOutside

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseDown() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appActivated(app) }
        }
    }

    public func stop() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        mouseMonitor = nil
        activationObserver = nil
        onOutside = nil
    }

    private func mouseDown() {
        if Self.isInMenuBar(NSEvent.mouseLocation) {
            lastMenuBarClick = Date()
        } else {
            onOutside?()
        }
    }

    private func appActivated(_ app: NSRunningApplication?) {
        if app?.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        // Clicking a revealed item often activates its app; don't collapse out from under it.
        if Date().timeIntervalSince(lastMenuBarClick) < 1 { return }
        onOutside?()
    }

    static func isInMenuBar(_ point: NSPoint) -> Bool {
        for screen in NSScreen.screens where screen.frame.contains(point) {
            let thickness = max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top, 24)
            return point.y >= screen.frame.maxY - thickness
        }
        return false
    }
}
