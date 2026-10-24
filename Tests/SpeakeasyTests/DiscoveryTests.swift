import AppKit
import XCTest
@testable import SpeakeasyKit

final class SectionClassifierTests: XCTestCase {
    private let seps = SeparatorFrames(hiddenMinX: 1000, alwaysHiddenMinX: 600, toggleMidX: 1400)

    func testItemsAreAssignedBySeparatorPosition() {
        let items = [item("Always", x: 100), item("Hidden", x: 700), item("Shown", x: 1100)]
        let result = SectionClassifier.classify(items, separators: seps)
        XCTAssertEqual(result.map(\.section), [.alwaysHidden, .hidden, .visible])
    }

    func testItemsPushedFarOffscreenKeepTheirOrder() {
        // Collapsed: separators are pushed left too, and so are the items beyond them.
        let collapsed = SeparatorFrames(hiddenMinX: -9000, alwaysHiddenMinX: -19000, toggleMidX: 1400)
        let items = [item("A", x: -19500), item("H", x: -9500), item("V", x: 1100)]
        XCTAssertEqual(SectionClassifier.classify(items, separators: collapsed).map(\.section), [.alwaysHidden, .hidden, .visible])
    }

    func testItemsOnOtherDisplaysAreDropped() {
        let other = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let items = [item("External", x: -500), item("Mine", x: 1100)]
        XCTAssertEqual(SectionClassifier.classify(items, separators: seps, otherScreens: [other]).map(\.id), ["Mine"])
    }
}

@MainActor
final class ItemDiscoveryTests: XCTestCase {
    private func window(_ owner: String, x: CGFloat, width: CGFloat = 30, id: UInt32, onscreen: Bool = true, title: String? = nil) -> [String: Any] {
        var info: [String: Any] = [
            kCGWindowLayer as String: Int(CGWindowLevelForKey(.statusWindow)),
            kCGWindowIsOnscreen as String: onscreen,
            kCGWindowOwnerPID as String: Int32(1),
            kCGWindowNumber as String: id,
            kCGWindowOwnerName as String: owner,
            kCGWindowBounds as String: CGRect(x: x, y: 0, width: width, height: 33).dictionaryRepresentation,
        ]
        if let title { info[kCGWindowName as String] = title }
        return info
    }

    private func service(_ windows: [[String: Any]], separators: SeparatorFrames?, own: Set<UInt32> = []) -> WindowListItemService {
        let fake = FakeSeparators()
        fake.separatorFrames = separators
        fake.ownWindowIDs = own
        let screen = ScreenInfo(cgFrame: CGRect(x: 0, y: 0, width: 1500, height: 900))
        return WindowListItemService(windows: FakeWindowList(windows: windows), separators: fake, screens: FakeScreens(infos: [screen]))
    }

    func testPushedOffItemsAreDiscoveredWithTheirSection() {
        let seps = SeparatorFrames(hiddenMinX: -9000, alwaysHiddenMinX: -19000, toggleMidX: 1400)
        let list = [
            window("Alpha", x: -19500, id: 1, onscreen: false),
            window("Beta", x: -9500, id: 2, onscreen: false),
            window("Gamma", x: 1100, id: 3),
            window("Placeholder", x: -2074, width: 5016, id: 4, onscreen: false),
        ]
        let items = service(list, separators: seps).currentItems()
        XCTAssertEqual(items.map(\.appName), ["Alpha", "Beta", "Gamma"])
        XCTAssertEqual(items.map(\.section), [.alwaysHidden, .hidden, .visible])
    }

    func testOwnItemsAreExcluded() {
        let seps = SeparatorFrames(hiddenMinX: 1000, alwaysHiddenMinX: 600, toggleMidX: 1400)
        let list = [window("Speakeasy", x: 1450, id: 9), window("Other", x: 1100, id: 3)]
        XCTAssertEqual(service(list, separators: seps, own: [9]).currentItems().map(\.appName), ["Other"])
    }

    func testBeforeLayoutOnlyOnscreenItemsAreReturned() {
        let list = [window("A", x: 100, id: 1), window("B", x: -500, width: 30, id: 2, onscreen: false)]
        XCTAssertEqual(service(list, separators: nil).currentItems().map(\.appName), ["A"])
    }

    func testUniqueTitleIsPartOfTheIdentity() {
        let list = [window("App", x: 100, id: 1, title: "Sync"), window("App", x: 200, id: 2, title: "Status")]
        let ids = WindowListItemService.items(from: list).map(\.id)
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(ids[0].hasSuffix("|Sync") && ids[1].hasSuffix("|Status"))
    }

    func testDuplicateTitlesFallBackToIndex() {
        let list = [window("App", x: 100, id: 1, title: "Item"), window("App", x: 200, id: 2, title: "Item")]
        XCTAssertEqual(WindowListItemService.items(from: list).map(\.id), ["App#0", "App#1"])
    }
}

@MainActor
final class ItemChangeObserverTests: XCTestCase {
    func testBurstOfNotificationsProducesOneDebouncedChange() {
        let scheduler = FakeScheduler()
        let workspace = NotificationCenter()
        let center = NotificationCenter()
        let observer = NotificationItemChangeObserver(scheduler: scheduler, debounce: 0.5, workspaceCenter: workspace, center: center)
        var changes = 0
        observer.onChange = { changes += 1 }
        observer.start()

        workspace.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspace.post(name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(changes, 0, "must not fire immediately")
        scheduler.advance(by: 1)
        XCTAssertEqual(changes, 1)

        observer.stop()
        workspace.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        scheduler.advance(by: 1)
        XCTAssertEqual(changes, 1)
    }
}
