import XCTest
@testable import SpeakeasyKit

@MainActor
final class NotchDetectorTests: XCTestCase {
    // 14" MacBook Pro-like: 1512 wide, notch from 650 to 862, 32 pt menu bar.
    private let notched = ScreenInfo(
        cgFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        auxiliaryLeftWidth: 650, auxiliaryRightWidth: 650, topInset: 32)
    private let plain = ScreenInfo(cgFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    private let detector = NotchDetector()

    func testNotchRectComesFromAuxiliaryWidths() {
        XCTAssertEqual(notched.notchRect, CGRect(x: 650, y: 0, width: 212, height: 32))
        XCTAssertNil(plain.notchRect)
    }

    func testItemsInUsableAreasAreFine() {
        let items = [item("A", x: 100), item("B", x: 1000)]
        XCTAssertTrue(detector.overflowingItems(in: items, screens: [notched]).isEmpty)
    }

    func testItemIntersectingNotchIsFlagged() {
        let items = [item("A", x: 100), item("Behind", x: 700)]
        XCTAssertEqual(detector.overflowingItems(in: items, screens: [notched]).map(\.id), ["Behind"])
    }

    func testItemStraddlingNotchEdgeIsFlagged() {
        let items = [item("Edge", x: 635, width: 30)]
        XCTAssertEqual(detector.overflowingItems(in: items, screens: [notched]).map(\.id), ["Edge"])
    }

    func testItemsPushedOffScreenBySeparatorAreNotFlagged() {
        let items = [item("Hidden", x: -400), item("Partly", x: -10)]
        XCTAssertTrue(detector.overflowingItems(in: items, screens: [notched]).isEmpty)
    }

    func testNoNotchMeansInactive() {
        let items = [item("A", x: 700)]
        XCTAssertTrue(detector.overflowingItems(in: items, screens: [plain]).isEmpty)
    }

    func testFakeMenuBarFeedsDetector() {
        let menuBar = FakeMenuBar(items: [item("Behind", x: 720)])
        XCTAssertEqual(detector.overflowingItems(in: menuBar.currentItems(), screens: [notched]).count, 1)
    }
}
