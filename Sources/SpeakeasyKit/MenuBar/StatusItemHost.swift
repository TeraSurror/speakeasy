import AppKit

public enum ToggleClick {
    case primary
    case alternate
    case menu
}

/// Owns the two `NSStatusItem`s. The toggle is created first so the separator lands to its left.
@MainActor
public final class StatusItemHost: StatusItemHosting {
    static let hiddenSeparatorLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 10
    static let invisibleLength: CGFloat = 2

    public var onToggleClick: ((ToggleClick) -> Void)?

    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem
    private let badgeView: NSView
    private let clickTarget = ClickTarget()
    private var popover: NSPopover?
    private var lastHidden: Bool?
    private var latest = ToggleAppearance(icon: .martini, isHidden: false, showSeparator: true)
    private var animationTarget: Bool?
    private var animationTimer: Timer?
    private static let animationDuration: TimeInterval = 0.25

    public init() {
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "speakeasy.toggle"
        separatorItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        separatorItem.autosaveName = "speakeasy.separator"

        badgeView = NSView(frame: NSRect(x: 0, y: 0, width: 7, height: 7))
        badgeView.wantsLayer = true
        badgeView.layer?.backgroundColor = NSColor.systemRed.cgColor
        badgeView.layer?.cornerRadius = 3.5
        badgeView.isHidden = true

        if let button = toggleItem.button {
            clickTarget.owner = self
            button.target = clickTarget
            button.action = #selector(ClickTarget.clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.addSubview(badgeView)
            button.setAccessibilityLabel("Speakeasy")
            button.setAccessibilityHelp("Shows or hides the hidden menu bar items. Right-click for settings.")
        }
        separatorItem.button?.setAccessibilityElement(false)
    }

    // MARK: StatusItemHosting

    public func render(_ appearance: ToggleAppearance) {
        let symbol = appearance.icon.symbolName(isHidden: appearance.isHidden)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.isTemplate = true
        toggleItem.button?.image = image
        toggleItem.button?.setAccessibilityValue(appearance.isHidden ? "Items hidden" : "Items shown")
        layoutBadge(visible: appearance.hasBadge)

        latest = appearance
        let changed = lastHidden != nil && lastHidden != appearance.isHidden
        lastHidden = appearance.isHidden
        if changed && appearance.animates && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animateSeparator(toHidden: appearance.isHidden)
        } else if animationTarget == appearance.isHidden {
            // Already sliding to this state; finishing applies the latest appearance.
        } else {
            applySeparator(appearance)
        }
    }

    public var toggleIsRightOfSeparator: Bool {
        guard let toggle = toggleItem.button?.window?.frame,
              let separator = separatorItem.button?.window?.frame,
              toggle.width > 0, separator.width > 0 else { return true } // not laid out yet
        return toggle.minX >= separator.maxX - 1
    }

    // MARK: Separator

    private func applySeparator(_ appearance: ToggleAppearance) {
        stopAnimation()
        if appearance.isHidden {
            separatorItem.button?.image = nil
            separatorItem.length = Self.hiddenSeparatorLength
        } else if appearance.showSeparator {
            separatorItem.button?.image = Self.dividerImage
            separatorItem.length = Self.dividerLength
        } else {
            separatorItem.button?.image = nil
            separatorItem.length = Self.invisibleLength
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationTarget = nil
    }

    /// Items left of the separator are pushed along by its length. Any length of at least the screen
    /// width has them all off-screen, so we tween between that and the resting length.
    private func animateSeparator(toHidden hidden: Bool) {
        stopAnimation()
        let width = toggleItem.button?.window?.screen?.frame.width ?? NSScreen.main?.frame.width ?? 1600
        let full = width + 40
        let rest = latest.showSeparator ? Self.dividerLength : Self.invisibleLength
        let from = hidden ? rest : full
        let to = hidden ? full : rest
        separatorItem.button?.image = nil
        separatorItem.length = from
        animationTarget = hidden

        let start = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let t = min(Date().timeIntervalSince(start) / Self.animationDuration, 1)
                let eased = t * t * (3 - 2 * t)
                if t >= 1 {
                    self.applySeparator(self.latest) // snaps to the exact resting (or fully hidden) length
                } else {
                    self.separatorItem.length = from + (to - from) * eased
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common) // keep running while a menu is tracking
        animationTimer = timer
    }

    // MARK: Extras used by the app controller

    var separatorWindowNumber: Int? { separatorItem.button?.window?.windowNumber }

    func popUp(_ menu: NSMenu) {
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    func showPopover(_ controller: NSViewController) {
        guard let button = toggleItem.button else { return }
        popover?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        self.popover = popover
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: Private

    private func layoutBadge(visible: Bool) {
        guard let button = toggleItem.button else { return }
        badgeView.isHidden = !visible
        badgeView.frame.origin = NSPoint(x: button.bounds.maxX - 9, y: button.bounds.maxY - 10)
    }

    fileprivate func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            onToggleClick?(.menu)
        } else if event?.modifierFlags.contains(.option) == true {
            onToggleClick?(.alternate)
        } else {
            onToggleClick?(.primary)
        }
    }

    private static let dividerImage: NSImage = {
        let image = NSImage(size: NSSize(width: 4, height: 14), flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: NSRect(x: 1.5, y: 0, width: 1, height: rect.height), xRadius: 0.5, yRadius: 0.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

private final class ClickTarget: NSObject {
    weak var owner: StatusItemHost?

    @MainActor @objc func clicked(_ sender: Any?) {
        owner?.handleClick()
    }
}
