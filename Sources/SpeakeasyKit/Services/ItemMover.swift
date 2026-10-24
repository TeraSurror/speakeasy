import AppKit

/// Moves status items by synthesizing a ⌘-drag, the same gesture a person uses. Timing-sensitive, so the drag is
/// stepped in small increments, the result is verified by re-reading positions, and a failed move is retried once.
@MainActor
public final class ItemMover: ItemMoving {
    static let dragSteps = 12
    static let attempts = 2

    private let permission: AccessibilityPermission
    private let events: EventPosting
    private let items: MenuBarItemService
    private let separators: SeparatorLocating
    private let screens: ScreenProviding
    private let session: LayoutSessionControlling
    private let pause: (TimeInterval) async -> Void
    private var isMoving = false

    public init(
        permission: AccessibilityPermission, events: EventPosting, items: MenuBarItemService,
        separators: SeparatorLocating, screens: ScreenProviding, session: LayoutSessionControlling,
        pause: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.permission = permission
        self.events = events
        self.items = items
        self.separators = separators
        self.screens = screens
        self.session = session
        self.pause = pause
    }

    public func move(itemID: String, to section: Section) async -> MoveResult {
        guard permission.isTrusted else { return .failed(.noPermission) }
        guard !isMoving else { return .failed(.busy) }
        isMoving = true
        session.beginLayoutSession()
        await pause(0.6) // let the sections slide open and the items settle
        let result = await attemptMoves(itemID: itemID, to: section)
        session.endLayoutSession()
        isMoving = false
        if case .failed(let failure) = result {
            Log.mover.error("Move of \(itemID) to \(section.rawValue) failed: \(String(describing: failure))")
        }
        return result
    }

    private func attemptMoves(itemID: String, to section: Section) async -> MoveResult {
        var failure = MoveFailure.itemNotFound
        for _ in 0..<Self.attempts {
            guard let frames = separators.separatorFrames else { return .failed(.separatorsUnavailable) }
            guard let item = items.currentItems().first(where: { $0.id == itemID }) else { return .failed(.itemNotFound) }
            if item.section == section { return .moved }
            let notches = screens.screens.compactMap(\.notchRect)
            guard let plan = MovePlanner.plan(for: item, to: section, separators: frames, notches: notches) else {
                return .failed(.notReachable)
            }
            await drag(plan)
            await pause(0.4)
            let actual = items.currentItems().first(where: { $0.id == itemID })?.section
            if actual == section { return .moved }
            failure = .didNotLand(actual: actual)
        }
        return .failed(failure)
    }

    private func drag(_ plan: DragPlan) async {
        let original = events.cursorLocation
        events.post(SyntheticMouseEvent(.move, at: plan.start))
        await pause(0.05)
        events.post(SyntheticMouseEvent(.down, at: plan.start))
        await pause(0.05)
        for step in 1...Self.dragSteps {
            let t = CGFloat(step) / CGFloat(Self.dragSteps)
            let point = CGPoint(x: plan.start.x + (plan.end.x - plan.start.x) * t, y: plan.start.y + (plan.end.y - plan.start.y) * t)
            events.post(SyntheticMouseEvent(.dragged, at: point))
            await pause(0.012)
        }
        await pause(0.05)
        events.post(SyntheticMouseEvent(.up, at: plan.end))
        events.warpCursor(to: original)
    }
}
