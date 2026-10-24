import AppKit
import CoreGraphics
import Foundation

/// Where the pointer counts as "over empty menu bar space" (F12). Pure, so it can be tested.
///
/// The zone is the part of the bar between the frontmost app's menu titles and Speakeasy's side of the
/// status items. Without Accessibility the width of the app menus is unknown, so it errs on the safe side:
/// right of the notch on notched displays, and the right half of the bar otherwise.
public enum HoverZone {
    static let minimumBarHeight: CGFloat = 24
    /// Keeps the zone clear of the status item the pointer is about to enter.
    static let rightMargin: CGFloat = 4

    /// - Parameter rightLimit: x of the leftmost visible status item on that display, if known.
    public static func contains(_ point: CGPoint, screens: [ScreenInfo], rightLimit: (ScreenInfo) -> CGFloat?) -> Bool {
        guard let screen = screens.first(where: { $0.cgFrame.contains(point) }) else { return false }
        let barHeight = max(screen.topInset, minimumBarHeight)
        guard point.y >= screen.cgFrame.minY, point.y < screen.cgFrame.minY + barHeight else { return false }
        let left = screen.notchRect?.maxX ?? screen.cgFrame.midX
        let right = min(rightLimit(screen) ?? screen.cgFrame.maxX, screen.cgFrame.maxX) - rightMargin
        return point.x >= left && point.x < right
    }
}

/// Reveals the hidden section when the pointer rests on empty menu bar space for `dwell` seconds.
@MainActor
public final class ShowOnHoverController {
    public nonisolated static let defaultDwell: TimeInterval = 0.3

    private let monitor: PointerMonitoring
    private let screens: ScreenProviding
    private let scheduler: Scheduling
    private let dwell: TimeInterval
    private let rightLimit: (ScreenInfo) -> CGFloat?
    private let reveal: () -> Void
    private var pending: TaskHandle?
    private var fired = false
    private var running = false

    public init(
        monitor: PointerMonitoring, screens: ScreenProviding, scheduler: Scheduling,
        dwell: TimeInterval = ShowOnHoverController.defaultDwell,
        rightLimit: @escaping (ScreenInfo) -> CGFloat?, reveal: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.screens = screens
        self.scheduler = scheduler
        self.dwell = dwell
        self.rightLimit = rightLimit
        self.reveal = reveal
        monitor.onMove = { [weak self] point in self?.moved(to: point) }
    }

    /// Listens only while the feature is on and there is something to reveal.
    public func setActive(_ active: Bool) {
        guard active != running else { return }
        running = active
        if active {
            monitor.start()
        } else {
            monitor.stop()
            cancel()
            fired = false
        }
    }

    private func moved(to point: CGPoint) {
        guard HoverZone.contains(point, screens: screens.screens, rightLimit: rightLimit) else {
            cancel()
            fired = false // leaving the zone re-arms it
            return
        }
        guard pending == nil, !fired else { return }
        pending = scheduler.schedule(after: dwell) { [weak self] in
            guard let self else { return }
            pending = nil
            fired = true
            reveal()
        }
    }

    private func cancel() {
        pending?.cancel()
        pending = nil
    }
}

/// Global mouse-moved events need no permission. The monitor exists only between `start` and `stop`.
@MainActor
public final class NSEventPointerMonitor: PointerMonitoring {
    public var onMove: ((CGPoint) -> Void)?
    private var monitor: Any?

    public init() {}

    public func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
    }

    public func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func report() {
        guard let primary = NSScreen.screens.first else { return }
        let p = NSEvent.mouseLocation
        onMove?(CGPoint(x: p.x, y: primary.frame.height - p.y))
    }
}
