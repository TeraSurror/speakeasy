import AppKit
import Combine
import SwiftUI

/// Composition root: wires the services to the menu bar. No macOS API is called directly from SwiftUI views.
@MainActor
final class AppController: LayoutSessionControlling {
    let model: AppModel

    private let scheduler: Scheduling = DispatchScheduler()
    private let screens: ScreenProviding = NSScreenProvider()
    private var itemService: MenuBarItemService?
    private var itemObserver: ItemChangeObserving?
    private var hover: ShowOnHoverController?
    private var layoutSession: (wasHidden: Bool, wasAlwaysRevealed: Bool)?
    private let hotkeys: HotkeyRegistering
    private let detector = NotchDetector()
    private let outsideMonitor = OutsideInteractionMonitor()
    private let windows = WindowPresenter()

    private var host: StatusItemHost?
    private var sections: SectionController?
    private var rehide: RehideTimer?
    private var notchRefresh: TaskHandle?
    private var acknowledgedNotchSignature: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let hotkeys = KeyboardShortcutsHotkeys()
        self.hotkeys = hotkeys
        self.model = AppModel(
            store: JSONSettingsStore(), loginItems: SMLoginItemService(),
            hotkeys: hotkeys, conflicts: SystemHotkeyConflictChecker()
        )
    }

    func start() {
        guard host == nil else { return }
        let settings = model.settings

        let host = StatusItemHost()
        self.host = host
        itemService = WindowListItemService(separators: host, screens: screens)
        let sections = SectionController(
            host: host, scheduler: scheduler, icon: settings.toggleIcon, showSeparator: settings.showSeparator,
            animates: settings.animateTransitions)
        self.sections = sections
        sections.onHiddenChanged = { [weak self] hidden in self?.hiddenChanged(hidden) }
        // Revealing or collapsing the always-hidden section follows the same auto-rehide rules as F3.
        sections.onAlwaysHiddenChanged = { [weak self] _ in
            if self?.layoutSession == nil { self?.rehide?.arm() }
            self?.scheduleNotchRefresh(after: 0.5)
        }

        rehide = RehideTimer(scheduler: scheduler, menus: PopupMenuDetector()) { [weak self] in
            self?.sections?.hide()
        }

        host.onToggleClick = { [weak self] click in self?.handle(click) }
        hotkeys.setHandler(for: .toggleHiddenSection) { [weak self] in self?.sections?.toggle() }
        hotkeys.setHandler(for: .toggleAlwaysHidden) { [weak self] in self?.sections?.toggleAlwaysHidden() }

        model.showWelcome = { [weak self] in self.map { $0.windows.showOnboarding(model: $0.model) } }
        model.diagnostics = { [weak self] in self.map { Diagnostics.report(model: $0.model, screens: $0.screens) } ?? "" }

        model.$settings
            .removeDuplicates()
            .sink { [weak self] in self?.apply($0) }
            .store(in: &cancellables)

        sections.start(restoringHidden: settings.isHidden)

        model.spacingControl = DefaultsIconSpacing()
        let permission = SystemAccessibilityPermission()
        model.accessibility = permission
        model.mover = ItemMover(
            permission: permission, events: CGEventPoster(), items: itemService!, separators: host,
            screens: screens, session: self)
        model.refreshItems = { [weak self] in self?.scheduleNotchRefresh(after: 0.2) }
        model.iconProvider = { item in NSRunningApplication(processIdentifier: item.pid)?.icon }

        hover = ShowOnHoverController(
            monitor: NSEventPointerMonitor(), screens: screens, scheduler: scheduler,
            rightLimit: { [weak self] screen in self?.hoverRightLimit(on: screen) },
            reveal: { [weak self] in self?.sections?.show() })
        updateHover()

        let observer = NotificationItemChangeObserver(scheduler: scheduler)
        observer.onChange = { [weak self] in self?.scheduleNotchRefresh() }
        observer.start()
        itemObserver = observer
        scheduleNotchRefresh(after: 1.5)

        if !settings.onboardingCompleted {
            windows.showOnboarding(model: model)
        }
    }

    // MARK: Settings changes

    private func apply(_ settings: Settings) {
        updateHover(showOnHover: settings.showOnHover)
        sections?.update(icon: settings.toggleIcon, showSeparator: settings.showSeparator, animates: settings.animateTransitions)
        rehide?.delay = settings.rehideEnabled ? settings.rehideDelay : nil
        if sections?.isHidden == false && layoutSession == nil {
            rehide?.arm()
            updateOutsideMonitor(shown: true, enabled: settings.rehideOnClickOutside)
        }
    }

    private func hiddenChanged(_ hidden: Bool) {
        updateHover(isHidden: hidden)
        if layoutSession != nil { return } // the session restores the real state when it ends
        model.settings.isHidden = hidden
        if hidden {
            rehide?.disarm()
            outsideMonitor.stop()
        } else {
            rehide?.arm()
            updateOutsideMonitor(shown: true, enabled: model.settings.rehideOnClickOutside)
        }
        scheduleNotchRefresh(after: 0.5)
    }

    // MARK: Layout session

    func beginLayoutSession() {
        guard layoutSession == nil, let sections else { return }
        layoutSession = (sections.isHidden, sections.isAlwaysHiddenRevealed)
        rehide?.disarm()
        outsideMonitor.stop()
        sections.showAlwaysHidden()
    }

    func endLayoutSession() {
        guard let session = layoutSession else { return }
        layoutSession = nil
        if session.wasHidden {
            sections?.hide()
        } else if !session.wasAlwaysRevealed {
            sections?.hideAlwaysHidden()
        }
        if sections?.isHidden == false {
            rehide?.arm()
            updateOutsideMonitor(shown: true, enabled: model.settings.rehideOnClickOutside)
        }
        updateHover()
        scheduleNotchRefresh(after: 0.5)
    }

    private func updateHover(showOnHover: Bool? = nil, isHidden: Bool? = nil) {
        let enabled = showOnHover ?? model.settings.showOnHover
        let hidden = isHidden ?? sections?.isHidden ?? false
        hover?.setActive(enabled && hidden)
    }

    /// The pointer must stay left of the leftmost visible status item and of the toggle.
    private func hoverRightLimit(on screen: ScreenInfo) -> CGFloat? {
        let visible = model.items.filter {
            $0.section == .visible && $0.frame.midX >= screen.cgFrame.minX && $0.frame.midX < screen.cgFrame.maxX
        }
        let toggle = host?.separatorFrames.map { $0.toggleMidX - 15 }
        return ([toggle] + visible.map { Optional($0.frame.minX) }).compactMap { $0 }.min()
    }

    private func updateOutsideMonitor(shown: Bool, enabled: Bool) {
        if shown && enabled {
            outsideMonitor.start { [weak self] in self?.sections?.hide() }
        } else {
            outsideMonitor.stop()
        }
    }

    // MARK: Clicks and menu

    private func handle(_ click: ToggleClick) {
        switch click {
        case .menu:
            showMenu()
        case .alternate:
            sections?.toggleAlwaysHidden()
        case .primary:
            if let signature = notchSignature, signature != acknowledgedNotchSignature {
                acknowledgedNotchSignature = signature
                showNotchExplanation()
            } else {
                sections?.toggle()
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if !model.notchItems.isEmpty {
            menu.addItem(ActionMenuItem(title: "Items Hidden by the Notch…") { [weak self] in self?.showNotchExplanation() })
            menu.addItem(.separator())
        }
        let toggleTitle = sections?.isHidden == false ? "Hide Items" : "Show Hidden Items"
        menu.addItem(ActionMenuItem(title: toggleTitle) { [weak self] in self?.sections?.toggle() })
        let alwaysTitle = sections?.isAlwaysHiddenRevealed == true ? "Hide Always-Hidden Items" : "Show Always-Hidden Items"
        menu.addItem(ActionMenuItem(title: alwaysTitle) { [weak self] in self?.sections?.toggleAlwaysHidden() })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Settings…", keyEquivalent: ",") { [weak self] in self?.openSettings() })
        menu.addItem(ActionMenuItem(title: "Welcome Guide…") { [weak self] in self.map { $0.windows.showOnboarding(model: $0.model) } })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Quit Speakeasy", keyEquivalent: "q") { NSApp.terminate(nil) })
        host?.popUp(menu)
    }

    private func openSettings() {
        windows.showSettings(model: model)
    }

    // MARK: Notch

    private var notchSignature: String? {
        model.notchItems.isEmpty ? nil : model.notchItems.map(\.id).sorted().joined(separator: ",")
    }

    private func showNotchExplanation() {
        let names = Array(Set(model.notchItems.map(\.appName))).sorted()
        let controller = NSHostingController(rootView: NotchInfoView(appNames: names))
        // Let a menu that is still closing finish first, or the popover can be dismissed immediately.
        scheduler.schedule(after: 0.15) { [weak self] in self?.host?.showPopover(controller) }
    }

    private func scheduleNotchRefresh(after delay: TimeInterval = 0.5) {
        notchRefresh?.cancel()
        notchRefresh = scheduler.schedule(after: delay) { [weak self] in self?.refreshNotch() }
    }

    private func refreshNotch() {
        guard let itemService else { return }
        let items = itemService.currentItems()
        if items != model.items {
            let summary = items.map { "\($0.appName)[\($0.title ?? "-")]=\($0.section.rawValue)" }.joined(separator: ", ")
            Log.discovery.info("Discovered \(items.count) items: \(summary, privacy: .public)")
            model.items = items
        }
        let affected = detector.overflowingItems(in: items, screens: screens.screens)
        if affected != model.notchItems {
            Log.discovery.info("Notch overflow: \(affected.map(\.appName).joined(separator: ", "))")
            model.notchItems = affected
        }
        sections?.setBadge(!affected.isEmpty)
    }
}
