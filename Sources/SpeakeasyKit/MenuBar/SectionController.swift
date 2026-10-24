import Foundation

/// The single place that decides when the hidden section is shown or hidden.
/// If the separator trick ever breaks on a new macOS release, this is the only thing to swap.
@MainActor
public final class SectionController {
    public private(set) var appearance: ToggleAppearance
    public var onHiddenChanged: ((Bool) -> Void)?
    public var onAlwaysHiddenChanged: ((Bool) -> Void)?

    private let host: StatusItemHosting
    private let scheduler: Scheduling
    private var restoreTask: TaskHandle?

    public var isHidden: Bool { appearance.isHidden }
    public var isAlwaysHiddenRevealed: Bool { appearance.alwaysHiddenRevealed }

    public init(host: StatusItemHosting, scheduler: Scheduling, icon: ToggleIcon, showSeparator: Bool, animates: Bool = true) {
        self.host = host
        self.scheduler = scheduler
        self.appearance = ToggleAppearance(icon: icon, isHidden: false, showSeparator: showSeparator, animates: animates)
    }

    /// Reveals everything first (both separators at their resting length), so a previous crash can never
    /// leave items stranded off-screen, then restores the saved state once the items have laid out.
    /// The always-hidden section always starts collapsed.
    public func start(restoringHidden hidden: Bool, settleDelay: TimeInterval = 0.5) {
        appearance.isHidden = false
        appearance.alwaysHiddenRevealed = true
        host.render(appearance)
        restoreTask = scheduler.schedule(after: settleDelay) { [weak self] in
            self?.settle(hidden: hidden)
        }
    }

    private func settle(hidden: Bool) {
        restoreTask = nil
        guard host.toggleIsRightOfSeparator else {
            Log.sections.notice("Refusing to collapse: the toggle sits left of a separator")
            return
        }
        appearance.alwaysHiddenRevealed = false
        appearance.isHidden = hidden
        host.render(appearance)
        if hidden { onHiddenChanged?(true) }
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

    /// Reveals the always-hidden section, along with the normal hidden section.
    public func showAlwaysHidden() {
        guard !appearance.alwaysHiddenRevealed else { return }
        let wasHidden = isHidden
        appearance.isHidden = false
        appearance.alwaysHiddenRevealed = true
        host.render(appearance)
        if wasHidden { onHiddenChanged?(false) }
        onAlwaysHiddenChanged?(true)
    }

    /// Collapses only the always-hidden section; the normal hidden section stays as it is.
    public func hideAlwaysHidden() {
        guard appearance.alwaysHiddenRevealed else { return }
        guard host.toggleIsRightOfSeparator else {
            Log.sections.notice("Refusing to hide: the toggle sits left of a separator")
            return
        }
        appearance.alwaysHiddenRevealed = false
        host.render(appearance)
        onAlwaysHiddenChanged?(false)
    }

    public func toggleAlwaysHidden() {
        isAlwaysHiddenRevealed ? hideAlwaysHidden() : showAlwaysHidden()
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
        if hidden { appearance.alwaysHiddenRevealed = false } // hiding collapses everything
        host.render(appearance)
        onHiddenChanged?(hidden)
    }
}
