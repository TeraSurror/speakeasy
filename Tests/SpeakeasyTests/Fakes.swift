import Foundation
@testable import SpeakeasyKit

@MainActor
final class FakeScheduler: Scheduling {
    struct Pending {
        let due: TimeInterval
        let action: @MainActor () -> Void
        let handle: TaskHandle
    }

    private(set) var now: TimeInterval = 0
    private var pending: [Pending] = []

    var pendingCount: Int { pending.filter { !$0.handle.isCancelled }.count }

    func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TaskHandle {
        let handle = TaskHandle {}
        pending.append(Pending(due: now + interval, action: action, handle: handle))
        return handle
    }

    func advance(by interval: TimeInterval) {
        let target = now + interval
        while let next = pending.filter({ !$0.handle.isCancelled && $0.due <= target }).min(by: { $0.due < $1.due }) {
            now = next.due
            pending.removeAll { $0.handle === next.handle }
            next.action()
        }
        now = target
    }
}

@MainActor
final class FakeMenus: MenuOpenDetecting {
    var isMenuOpen = false
}

@MainActor
final class FakeHost: StatusItemHosting {
    var rendered: [ToggleAppearance] = []
    var toggleIsRightOfSeparator = true

    func render(_ appearance: ToggleAppearance) {
        rendered.append(appearance)
    }
}

struct FakeMenuBar: MenuBarItemService {
    var items: [MenuBarItem]
    func currentItems() -> [MenuBarItem] { items }
}

func item(_ name: String, x: CGFloat, width: CGFloat = 30, y: CGFloat = 0, height: CGFloat = 32) -> MenuBarItem {
    MenuBarItem(id: name, appName: name, frame: CGRect(x: x, y: y, width: width, height: height))
}
