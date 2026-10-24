import XCTest
@testable import SpeakeasyKit

@MainActor
final class FakePointer: PointerMonitoring {
    var onMove: ((CGPoint) -> Void)?
    private(set) var running = false
    func start() { running = true }
    func stop() { running = false }
    func move(_ x: CGFloat, _ y: CGFloat = 10) { onMove?(CGPoint(x: x, y: y)) }
}

final class HoverZoneTests: XCTestCase {
    private let notched = ScreenInfo(
        cgFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        auxiliaryLeftWidth: 650, auxiliaryRightWidth: 650, topInset: 32)
    private let plain = ScreenInfo(cgFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))

    func testEmptySpaceRightOfNotchIsInZone() {
        XCTAssertTrue(HoverZone.contains(CGPoint(x: 900, y: 10), screens: [notched]) { _ in 1200 })
    }

    func testAppMenuTitlesAndNotchAreOutsideTheZone() {
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 100, y: 10), screens: [notched]) { _ in 1200 })
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 700, y: 10), screens: [notched]) { _ in 1200 })
    }

    func testOverStatusItemsIsOutsideTheZone() {
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 1250, y: 10), screens: [notched]) { _ in 1200 })
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 1198, y: 10), screens: [notched]) { _ in 1200 }, "margin before the first item")
    }

    func testBelowTheMenuBarIsOutsideTheZone() {
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 900, y: 200), screens: [notched]) { _ in 1200 })
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 1500, y: 30), screens: [plain]) { _ in 1700 }, "plain bar is 24 pt")
    }

    func testPlainDisplayUsesTheRightHalf() {
        XCTAssertFalse(HoverZone.contains(CGPoint(x: 500, y: 10), screens: [plain]) { _ in 1700 })
        XCTAssertTrue(HoverZone.contains(CGPoint(x: 1300, y: 10), screens: [plain]) { _ in 1700 })
    }

    func testPointOnNoScreenIsOutside() {
        XCTAssertFalse(HoverZone.contains(CGPoint(x: -50, y: 10), screens: [plain]) { _ in nil })
    }
}

@MainActor
final class ShowOnHoverControllerTests: XCTestCase {
    private var pointer: FakePointer!
    private var scheduler: FakeScheduler!
    private var controller: ShowOnHoverController!
    private var reveals = 0

    override func setUp() async throws {
        pointer = FakePointer()
        scheduler = FakeScheduler()
        reveals = 0
        let screen = ScreenInfo(cgFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        controller = ShowOnHoverController(
            monitor: pointer, screens: FakeScreens(infos: [screen]), scheduler: scheduler,
            rightLimit: { _ in 1700 }, reveal: { [unowned self] in reveals += 1 })
        controller.setActive(true)
    }

    func testRevealsAfterTheDwell() {
        pointer.move(1300)
        scheduler.advance(by: 0.29)
        XCTAssertEqual(reveals, 0)
        scheduler.advance(by: 0.02)
        XCTAssertEqual(reveals, 1)
    }

    func testLeavingBeforeTheDwellCancels() {
        pointer.move(1300)
        scheduler.advance(by: 0.2)
        pointer.move(300)
        scheduler.advance(by: 1)
        XCTAssertEqual(reveals, 0)
    }

    func testMovingWithinTheZoneDoesNotRestartTheDwell() {
        pointer.move(1300)
        scheduler.advance(by: 0.2)
        pointer.move(1310)
        scheduler.advance(by: 0.15)
        XCTAssertEqual(reveals, 1)
    }

    func testFiresOncePerVisitAndRearmsAfterLeaving() {
        pointer.move(1300)
        scheduler.advance(by: 0.4)
        pointer.move(1320)
        scheduler.advance(by: 1)
        XCTAssertEqual(reveals, 1)
        pointer.move(300)
        pointer.move(1300)
        scheduler.advance(by: 0.4)
        XCTAssertEqual(reveals, 2)
    }

    func testMonitorRunsOnlyWhileActive() {
        XCTAssertTrue(pointer.running)
        controller.setActive(false)
        XCTAssertFalse(pointer.running)
    }

    func testDeactivatingCancelsAPendingReveal() {
        pointer.move(1300)
        controller.setActive(false)
        scheduler.advance(by: 1)
        XCTAssertEqual(reveals, 0)
    }
}
