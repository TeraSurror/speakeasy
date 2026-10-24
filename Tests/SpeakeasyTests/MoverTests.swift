import XCTest
@testable import SpeakeasyKit

final class MovePlannerTests: XCTestCase {
    // always | hidden | visible, with the toggle at the far right
    private let seps = SeparatorFrames(hiddenMinX: 800, alwaysHiddenMinX: 400, toggleMidX: 1400, hiddenMaxX: 810)

    private func menuItem(x: CGFloat, width: CGFloat = 30) -> MenuBarItem {
        MenuBarItem(id: "A", appName: "A", frame: CGRect(x: x, y: 0, width: width, height: 32))
    }

    func testGrabsTheCenterAndDropsJustLeftOfTheTargetSeparator() {
        let plan = MovePlanner.plan(for: menuItem(x: 1000), to: .hidden, separators: seps)
        XCTAssertEqual(plan, DragPlan(start: CGPoint(x: 1015, y: 16), end: CGPoint(x: 799, y: 16)))
        XCTAssertEqual(MovePlanner.plan(for: menuItem(x: 1000), to: .alwaysHidden, separators: seps)?.end.x, 399)
    }

    func testVisibleDropIsJustRightOfTheHiddenSeparator() {
        XCTAssertEqual(MovePlanner.plan(for: menuItem(x: 500), to: .visible, separators: seps)?.end.x, 812)
    }

    func testPartiallyCoveredItemIsGrabbedByItsVisibleSliver() {
        let notch = CGRect(x: 650, y: 0, width: 212, height: 32)
        let straddling = menuItem(x: 635, width: 40) // 635...675, 25 pt visible left of the notch
        XCTAssertEqual(MovePlanner.plan(for: straddling, to: .hidden, separators: seps, notches: [notch])?.start.x, 642.5)
    }

    func testFullyCoveredItemCannotBeGrabbed() {
        let notch = CGRect(x: 650, y: 0, width: 212, height: 32)
        XCTAssertNil(MovePlanner.plan(for: menuItem(x: 700), to: .hidden, separators: seps, notches: [notch]))
    }
}

@MainActor
private final class FakePermission: AccessibilityPermission {
    var isTrusted = true
    private(set) var prompts = 0
    func requestPrompt() { prompts += 1 }
}

@MainActor
private final class FakeSession: LayoutSessionControlling {
    private(set) var log: [String] = []
    func beginLayoutSession() { log.append("begin") }
    func endLayoutSession() { log.append("end") }
}

/// A menu bar whose single item changes section when a drag ends, unless told to ignore drags.
@MainActor
private final class DraggableMenuBar: MenuBarItemService, EventPosting {
    var item = MenuBarItem(id: "A", appName: "A", frame: CGRect(x: 1000, y: 0, width: 30, height: 32), section: .visible)
    var landsOnDrop: [Section?] = []   // per-drag outcome; nil keeps the section
    private(set) var events: [SyntheticMouseEvent] = []
    private(set) var warped: [CGPoint] = []
    var cursorLocation = CGPoint(x: 5, y: 6)

    func currentItems() -> [MenuBarItem] { [item] }

    func post(_ event: SyntheticMouseEvent) {
        events.append(event)
        if event.kind == .up, !landsOnDrop.isEmpty, let outcome = landsOnDrop.removeFirst() { item.section = outcome }
    }

    func warpCursor(to location: CGPoint) { warped.append(location) }
}

@MainActor
final class ItemMoverTests: XCTestCase {
    private var bar: DraggableMenuBar!
    private var permission: FakePermission!
    private var session: FakeSession!
    private var separators: FakeSeparators!
    private var mover: ItemMover!

    override func setUp() async throws {
        bar = DraggableMenuBar()
        permission = FakePermission()
        session = FakeSession()
        separators = FakeSeparators()
        separators.separatorFrames = SeparatorFrames(hiddenMinX: 800, alwaysHiddenMinX: 400, toggleMidX: 1400)
        let screen = ScreenInfo(cgFrame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        mover = ItemMover(
            permission: permission, events: bar, items: bar, separators: separators,
            screens: FakeScreens(infos: [screen]), session: session, pause: { _ in })
    }

    func testSuccessfulMoveDragsWithCommandAndRestoresTheCursor() async {
        bar.landsOnDrop = [.hidden]
        let result = await mover.move(itemID: "A", to: .hidden)
        XCTAssertEqual(result, .moved)
        XCTAssertTrue(bar.events.allSatisfy(\.command))
        XCTAssertEqual(bar.events.map(\.kind).first, .move)
        XCTAssertEqual(bar.events.filter { $0.kind == .down }.count, 1)
        XCTAssertEqual(bar.events.last?.kind, .up)
        XCTAssertEqual(bar.warped, [CGPoint(x: 5, y: 6)])
        XCTAssertEqual(session.log, ["begin", "end"])
    }

    func testDragIsSteppedInSmallIncrements() async {
        bar.landsOnDrop = [.hidden]
        _ = await mover.move(itemID: "A", to: .hidden)
        let drags = bar.events.filter { $0.kind == .dragged }
        XCTAssertEqual(drags.count, ItemMover.dragSteps)
        XCTAssertEqual(drags.last?.location.x, 799)
    }

    func testRetriesOnceThenSucceeds() async {
        bar.landsOnDrop = [nil, .hidden]
        let result = await mover.move(itemID: "A", to: .hidden)
        XCTAssertEqual(result, .moved)
        XCTAssertEqual(bar.events.filter { $0.kind == .down }.count, 2)
    }

    func testFailsAfterTheRetry() async {
        bar.landsOnDrop = [nil, nil, .hidden] // a third attempt must never happen
        let result = await mover.move(itemID: "A", to: .hidden)
        XCTAssertEqual(result, .failed(.didNotLand(actual: .visible)))
        XCTAssertEqual(bar.events.filter { $0.kind == .down }.count, 2)
        XCTAssertEqual(session.log, ["begin", "end"], "the session is always closed")
    }

    func testNoPermissionDoesNothing() async {
        permission.isTrusted = false
        let result = await mover.move(itemID: "A", to: .hidden)
        XCTAssertEqual(result, .failed(.noPermission))
        XCTAssertTrue(bar.events.isEmpty)
        XCTAssertTrue(session.log.isEmpty)
    }

    func testAlreadyInSectionIsANoOp() async {
        let result = await mover.move(itemID: "A", to: .visible)
        XCTAssertEqual(result, .moved)
        XCTAssertTrue(bar.events.isEmpty)
    }

    func testUnknownItemFails() async {
        let result = await mover.move(itemID: "nope", to: .hidden)
        XCTAssertEqual(result, .failed(.itemNotFound))
    }

    func testItemBehindTheNotchIsNotReachable() async {
        let notched = ScreenInfo(
            cgFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            auxiliaryLeftWidth: 650, auxiliaryRightWidth: 650, topInset: 32)
        mover = ItemMover(
            permission: permission, events: bar, items: bar, separators: separators,
            screens: FakeScreens(infos: [notched]), session: session, pause: { _ in })
        bar.item.frame = CGRect(x: 700, y: 0, width: 30, height: 32)
        let result = await mover.move(itemID: "A", to: .hidden)
        XCTAssertEqual(result, .failed(.notReachable))
        XCTAssertTrue(bar.events.isEmpty)
    }
}
