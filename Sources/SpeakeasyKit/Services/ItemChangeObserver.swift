import AppKit

/// Watches app launch/quit and display changes, and reports them as one debounced change.
@MainActor
public final class NotificationItemChangeObserver: ItemChangeObserving {
    public var onChange: (() -> Void)?

    private let scheduler: Scheduling
    private let debounce: TimeInterval
    private let workspaceCenter: NotificationCenter
    private let center: NotificationCenter
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var pending: TaskHandle?

    public init(
        scheduler: Scheduling, debounce: TimeInterval = 0.5,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        center: NotificationCenter = .default
    ) {
        self.scheduler = scheduler
        self.debounce = debounce
        self.workspaceCenter = workspaceCenter
        self.center = center
    }

    public func start() {
        guard tokens.isEmpty else { return }
        let sources: [(NotificationCenter, Notification.Name)] = [
            (workspaceCenter, NSWorkspace.didLaunchApplicationNotification),
            (workspaceCenter, NSWorkspace.didTerminateApplicationNotification),
            (center, NSApplication.didChangeScreenParametersNotification),
        ]
        for (source, name) in sources {
            let token = source.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed() }
            }
            tokens.append((source, token))
        }
    }

    public func stop() {
        tokens.forEach { $0.0.removeObserver($0.1) }
        tokens = []
        pending?.cancel()
        pending = nil
    }

    private func changed() {
        pending?.cancel()
        pending = scheduler.schedule(after: debounce) { [weak self] in
            self?.pending = nil
            self?.onChange?()
        }
    }
}
