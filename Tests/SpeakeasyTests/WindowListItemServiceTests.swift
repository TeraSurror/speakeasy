import CoreGraphics
import XCTest
@testable import SpeakeasyKit

final class WindowListItemServiceTests: XCTestCase {
    private let layer = 25

    private func window(_ owner: String, x: CGFloat, width: CGFloat, id: UInt32, onscreen: Bool, layer: Int = 25) -> [String: Any] {
        let bounds = CGRect(x: x, y: 0, width: width, height: 33)
        return [
            kCGWindowLayer as String: layer,
            kCGWindowIsOnscreen as String: onscreen,
            kCGWindowOwnerPID as String: Int32(1),
            kCGWindowNumber as String: id,
            kCGWindowOwnerName as String: owner,
            kCGWindowBounds as String: bounds.dictionaryRepresentation,
        ]
    }

    func testOffscreenAndNonStatusWindowsAreIgnored() {
        let list = [
            window("Control Center", x: 3009, width: 40, id: 1, onscreen: true),
            window("Control Center", x: -2074, width: 5016, id: 2, onscreen: false),
            window("Dock", x: 100, width: 40, id: 3, onscreen: true, layer: 20),
        ]
        let items = WindowListItemService.items(from: list, statusLayer: layer)
        XCTAssertEqual(items.map(\.windowID), [1])
    }

    /// Regression: on a notched Mac, Control Center's off-screen 5016 pt wide placeholder windows
    /// spanned the notch and made the toggle show a false "overflow" badge.
    func testControlCenterPlaceholdersDoNotTriggerNotchBadge() {
        let builtIn = ScreenInfo(
            cgFrame: CGRect(x: 1920, y: 0, width: 1470, height: 956),
            auxiliaryLeftWidth: 646, auxiliaryRightWidth: 645, topInset: 33)
        let list = [
            window("Control Center", x: -2074, width: 5016, id: 1, onscreen: false),
            window("Control Center", x: -2106, width: 32, id: 2, onscreen: false),
            window("Control Center", x: 2942, width: 29, id: 3, onscreen: true),
            window("Control Center", x: 3240, width: 152, id: 4, onscreen: true),
        ]
        let items = WindowListItemService.items(from: list, statusLayer: layer)
        XCTAssertTrue(NotchDetector().overflowingItems(in: items, screens: [builtIn]).isEmpty)
    }

    func testIdsAreStablePerAppByLeftToRightIndex() {
        let list = [
            window("Foo", x: 300, width: 30, id: 2, onscreen: true),
            window("Foo", x: 100, width: 30, id: 1, onscreen: true),
        ]
        let items = WindowListItemService.items(from: list, statusLayer: layer)
        XCTAssertEqual(items.map(\.windowID), [1, 2])
        XCTAssertEqual(items.map(\.id), ["Foo#0", "Foo#1"])
    }
}
