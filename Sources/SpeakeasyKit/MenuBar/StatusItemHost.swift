import AppKit

public enum ToggleClick {
    case primary
    case alternate
    case menu
}

/// Owns the two `NSStatusItem`s. The toggle is created first so the separator lands to its left.
@MainActor
public final class StatusItemHost: StatusItemHosting, SeparatorLocating {
    static let hiddenSeparatorLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 10
    static let invisibleLength: CGFloat = 2

    public var onToggleClick: ((ToggleClick) -> Void)?

    private let toggleItem: NSStatusItem
    private let separator: SeparatorSlot
    private let alwaysHiddenSeparator: SeparatorSlot
    private let badgeView: NSView
    private let clickTarget = ClickTarget()
    private var popover: NSPopover?

    public init() {
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "speakeasy.toggle"
        // Created after the toggle and the separator, so macOS places it further left.
        let separatorItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        separatorItem.autosaveName = "speakeasy.separator"
        let alwaysHiddenItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        alwaysHiddenItem.autosaveName = "speakeasy.alwaysHiddenSeparator"
        separator = SeparatorSlot(item: separatorItem)
        alwaysHiddenSeparator = SeparatorSlot(item: alwaysHiddenItem)

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
        alwaysHiddenItem.button?.setAccessibilityElement(false)
    }

    // MARK: StatusItemHosting

    public func render(_ appearance: ToggleAppearance) {
        let symbol = appearance.icon.symbolName(isHidden: appearance.isHidden)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.isTemplate = true
        toggleItem.button?.image = image
        toggleItem.button?.setAccessibilityValue(appearance.isHidden ? "Items hidden" : "Items shown")
        layoutBadge(visible: appearance.hasBadge)

        // The always-hidden separator stays collapsed unless that section was explicitly revealed.
        separator.render(collapsed: appearance.isHidden, appearance: appearance, screenWidth: screenWidth)
        alwaysHiddenSeparator.render(
            collapsed: !appearance.alwaysHiddenRevealed, appearance: appearance, screenWidth: screenWidth)
    }

    public var toggleIsRightOfSeparator: Bool {
        guard let toggle = toggleItem.button?.window?.frame else { return true }
        return [separator, alwaysHiddenSeparator].allSatisfy { slot in
            guard let frame = slot.item.button?.window?.frame, toggle.width > 0, frame.width > 0 else { return true } // not laid out yet
            return toggle.minX >= frame.maxX - 1
        }
    }

    private var screenWidth: CGFloat {
        toggleItem.button?.window?.screen?.frame.width ?? NSScreen.main?.frame.width ?? 1600
    }

    // MARK: SeparatorLocating

    public var separatorFrames: SeparatorFrames? {
        guard let toggle = toggleItem.button?.window?.frame, toggle.width > 0,
              let hidden = separator.item.button?.window?.frame, hidden.width > 0,
              let always = alwaysHiddenSeparator.item.button?.window?.frame, always.width > 0 else { return nil }
        return SeparatorFrames(
            hiddenMinX: hidden.minX, alwaysHiddenMinX: always.minX, toggleMidX: toggle.midX, hiddenMaxX: hidden.maxX)
    }

    public var ownWindowIDs: Set<UInt32> {
        let numbers = [toggleItem, separator.item, alwaysHiddenSeparator.item].compactMap { $0.button?.window?.windowNumber }
        return Set(numbers.compactMap { UInt32(exactly: $0) })
    }

    // MARK: Extras used by the app controller


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

    fileprivate static let dividerImage: NSImage = {
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

/// One separator status item and its slide animation. Items left of a separator are pushed along by its
/// length, so any length of at least the screen width has them all off-screen.
@MainActor
private final class SeparatorSlot {
    let item: NSStatusItem

    private static let animationDuration: TimeInterval = 0.25
    private var lastCollapsed: Bool?
    private var animationTarget: Bool?
    private var timer: Timer?
    private var latest = ToggleAppearance(icon: .martini, isHidden: false, showSeparator: true)
    private var latestCollapsed = false
    private var latestWidth: CGFloat = 1600

    init(item: NSStatusItem) {
        self.item = item
    }

    func render(collapsed: Bool, appearance: ToggleAppearance, screenWidth: CGFloat) {
        latest = appearance
        latestCollapsed = collapsed
        latestWidth = screenWidth
        let changed = lastCollapsed != nil && lastCollapsed != collapsed
        lastCollapsed = collapsed
        if changed && appearance.animates && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animate(toCollapsed: collapsed)
        } else if animationTarget == collapsed {
            // Already sliding to this state; finishing applies the latest appearance.
        } else {
            apply()
        }
    }

    private var restLength: CGFloat {
        latest.showSeparator ? StatusItemHost.dividerLength : StatusItemHost.invisibleLength
    }

    private func apply() {
        stopAnimation()
        if latestCollapsed {
            item.button?.image = nil
            item.length = StatusItemHost.hiddenSeparatorLength
        } else if latest.showSeparator {
            item.button?.image = StatusItemHost.dividerImage
            item.length = StatusItemHost.dividerLength
        } else {
            item.button?.image = nil
            item.length = StatusItemHost.invisibleLength
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        animationTarget = nil
    }

    private func animate(toCollapsed collapsed: Bool) {
        stopAnimation()
        let full = latestWidth + 40
        let from = collapsed ? restLength : full
        let to = collapsed ? full : restLength
        item.button?.image = nil
        item.length = from
        animationTarget = collapsed

        let start = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let t = min(Date().timeIntervalSince(start) / Self.animationDuration, 1)
                let eased = t * t * (3 - 2 * t)
                if t >= 1 {
                    self.apply() // snaps to the exact resting (or fully hidden) length
                } else {
                    self.item.length = from + (to - from) * eased
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common) // keep running while a menu is tracking
        self.timer = timer
    }
}
