import AppKit
import Combine
import SwiftUI

/// Composition root: wires the services to the menu bar. No macOS API is called directly from SwiftUI views.
@MainActor
final class AppController {
    let model: AppModel

    private let scheduler: Scheduling = DispatchScheduler()
    private let screens: ScreenProviding = NSScreenProvider()
    private let itemService: MenuBarItemService = WindowListItemService()
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
        let sections = SectionController(
            host: host, scheduler: scheduler, icon: settings.toggleIcon, showSeparator: settings.showSeparator,
            animates: settings.animateTransitions)
        self.sections = sections
        sections.onHiddenChanged = { [weak self] hidden in self?.hiddenChanged(hidden) }

        rehide = RehideTimer(scheduler: scheduler, menus: PopupMenuDetector()) { [weak self] in
            self?.sections?.hide()
        }

        host.onToggleClick = { [weak self] click in self?.handle(click) }
        hotkeys.setHandler(for: .toggleHiddenSection) { [weak self] in self?.sections?.toggle() }

        model.showWelcome = { [weak self] in self.map { $0.windows.showOnboarding(model: $0.model) } }
        model.diagnostics = { [weak self] in self.map { Diagnostics.report(model: $0.model, screens: $0.screens) } ?? "" }

        model.$settings
            .removeDuplicates()
            .sink { [weak self] in self?.apply($0) }
            .store(in: &cancellables)

        sections.start(restoringHidden: settings.isHidden)

        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleNotchRefresh() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleNotchRefresh() }
            }
        }
        scheduleNotchRefresh(after: 1.5)

        if !settings.onboardingCompleted {
            windows.showOnboarding(model: model)
        }
    }

    // MARK: Settings changes

    private func apply(_ settings: Settings) {
        sections?.update(icon: settings.toggleIcon, showSeparator: settings.showSeparator, animates: settings.animateTransitions)
        rehide?.delay = settings.rehideEnabled ? settings.rehideDelay : nil
        if sections?.isHidden == false {
            rehide?.arm()
            updateOutsideMonitor(shown: true, enabled: settings.rehideOnClickOutside)
        }
    }

    private func hiddenChanged(_ hidden: Bool) {
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
        case .primary, .alternate:
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
        let ignored = host?.separatorWindowNumber.flatMap { UInt32(exactly: $0) }
        let items = itemService.currentItems().filter { $0.windowID != ignored }
        let affected = detector.overflowingItems(in: items, screens: screens.screens)
        if affected != model.notchItems {
            Log.discovery.info("Notch overflow: \(affected.map(\.appName).joined(separator: ", "))")
            model.notchItems = affected
        }
        sections?.setBadge(!affected.isEmpty)
    }
}
