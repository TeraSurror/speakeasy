import Foundation

/// The single place that decides when the hidden section is shown or hidden.
/// If the separator trick ever breaks on a new macOS release, this is the only thing to swap.
@MainActor
public final class SectionController {
    public private(set) var appearance: ToggleAppearance
    public var onHiddenChanged: ((Bool) -> Void)?

    private let host: StatusItemHosting
    private let scheduler: Scheduling
    private var restoreTask: TaskHandle?

    public var isHidden: Bool { appearance.isHidden }

    public init(host: StatusItemHosting, scheduler: Scheduling, icon: ToggleIcon, showSeparator: Bool, animates: Bool = true) {
        self.host = host
        self.scheduler = scheduler
        self.appearance = ToggleAppearance(icon: icon, isHidden: false, showSeparator: showSeparator, animates: animates)
    }

    /// Collapses the separator to its default length first, so a previous crash can never leave
    /// items stranded off-screen, then restores the saved state once the items have laid out.
    public func start(restoringHidden hidden: Bool, settleDelay: TimeInterval = 0.5) {
        appearance.isHidden = false
        host.render(appearance)
        guard hidden else { return }
        restoreTask = scheduler.schedule(after: settleDelay) { [weak self] in
            self?.hide()
        }
    }

    public func toggle() {
        isHidden ? show() : hide()
    }

    public func show() {
        guard isHidden else { return }
        setHidden(false)
    }

    public func hide() {
        guard !isHidden else { return }
        guard host.toggleIsRightOfSeparator else {
            Log.sections.notice("Refusing to hide: the toggle sits left of the separator")
            return
        }
        setHidden(true)
    }

    public func update(icon: ToggleIcon, showSeparator: Bool, animates: Bool = true) {
        guard icon != appearance.icon || showSeparator != appearance.showSeparator || animates != appearance.animates else { return }
        appearance.icon = icon
        appearance.showSeparator = showSeparator
        appearance.animates = animates
        host.render(appearance)
    }

    public func setBadge(_ hasBadge: Bool) {
        guard hasBadge != appearance.hasBadge else { return }
        appearance.hasBadge = hasBadge
        host.render(appearance)
    }

    private func setHidden(_ hidden: Bool) {
        restoreTask?.cancel()
        appearance.isHidden = hidden
        host.render(appearance)
        onHiddenChanged?(hidden)
    }
}
