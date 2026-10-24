import Foundation

/// Fires `onExpire` after `delay`. If a menu is open at that moment it waits for the menu to close
/// (checking every `recheckInterval`, never faster than 2 s) and then starts a fresh countdown.
@MainActor
public final class RehideTimer {
    public var delay: TimeInterval?
    public var recheckInterval: TimeInterval = 2

    private let scheduler: Scheduling
    private let menus: MenuOpenDetecting
    private let onExpire: () -> Void
    private var task: TaskHandle?

    public init(scheduler: Scheduling, menus: MenuOpenDetecting, onExpire: @escaping () -> Void) {
        self.scheduler = scheduler
        self.menus = menus
        self.onExpire = onExpire
    }

    public func arm() {
        disarm()
        guard let delay else { return }
        task = scheduler.schedule(after: delay) { [weak self] in self?.expired() }
    }

    public func disarm() {
        task?.cancel()
        task = nil
    }

    private func expired() {
        task = nil
        if menus.isMenuOpen {
            task = scheduler.schedule(after: recheckInterval) { [weak self] in self?.pollWhilePaused() }
        } else {
            onExpire()
        }
    }

    private func pollWhilePaused() {
        task = nil
        if menus.isMenuOpen {
            task = scheduler.schedule(after: recheckInterval) { [weak self] in self?.pollWhilePaused() }
        } else {
            arm()
        }
    }
}
