import XCTest
@testable import SpeakeasyKit

@MainActor
final class SectionControllerTests: XCTestCase {
    private var host: FakeHost!
    private var scheduler: FakeScheduler!
    private var controller: SectionController!
    private var changes: [Bool] = []

    override func setUp() async throws {
        host = FakeHost()
        scheduler = FakeScheduler()
        changes = []
        controller = SectionController(host: host, scheduler: scheduler, icon: .martini, showSeparator: true)
        controller.onHiddenChanged = { [unowned self] in changes.append($0) }
    }

    func testStartCollapsesBeforeRestoringHiddenState() {
        controller.start(restoringHidden: true)
        XCTAssertEqual(host.rendered.map(\.isHidden), [false], "first render must be the safe, revealed state")
        scheduler.advance(by: 1)
        XCTAssertEqual(host.rendered.map(\.isHidden), [false, true])
        XCTAssertEqual(changes, [true])
    }

    func testStartWithRevealedStateStaysRevealed() {
        controller.start(restoringHidden: false)
        scheduler.advance(by: 5)
        XCTAssertEqual(host.rendered.map(\.isHidden), [false, false])
        XCTAssertEqual(host.rendered.map(\.alwaysHiddenRevealed), [true, false], "starts fully revealed, then collapses always-hidden")
        XCTAssertTrue(changes.isEmpty)
    }

    func testAlwaysHiddenRevealsBothSectionsAndNotifies() {
        var always: [Bool] = []
        controller.onAlwaysHiddenChanged = { always.append($0) }
        controller.start(restoringHidden: true)
        scheduler.advance(by: 1)
        controller.showAlwaysHidden()
        XCTAssertFalse(controller.isHidden)
        XCTAssertTrue(controller.isAlwaysHiddenRevealed)
        XCTAssertEqual(changes, [true, false])
        XCTAssertEqual(always, [true])
    }

    func testHideAlwaysHiddenKeepsHiddenSectionShown() {
        controller.start(restoringHidden: false)
        scheduler.advance(by: 1)
        controller.showAlwaysHidden()
        controller.hideAlwaysHidden()
        XCTAssertFalse(controller.isHidden)
        XCTAssertFalse(controller.isAlwaysHiddenRevealed)
    }

    func testHidingCollapsesAlwaysHiddenToo() {
        controller.start(restoringHidden: false)
        scheduler.advance(by: 1)
        controller.showAlwaysHidden()
        controller.hide()
        XCTAssertTrue(controller.isHidden)
        XCTAssertFalse(controller.isAlwaysHiddenRevealed)
        XCTAssertEqual(host.rendered.last?.alwaysHiddenRevealed, false)
    }

    func testNeverCollapsesAlwaysHiddenWhenToggleIsLeftOfSeparator() {
        controller.start(restoringHidden: false)
        scheduler.advance(by: 1)
        controller.showAlwaysHidden()
        host.toggleIsRightOfSeparator = false
        controller.hideAlwaysHidden()
        XCTAssertTrue(controller.isAlwaysHiddenRevealed)
    }

    func testToggleBeforeSettleCancelsRestoreAndCollapsesEverything() {
        controller.start(restoringHidden: false)
        controller.hide()
        scheduler.advance(by: 1)
        XCTAssertTrue(controller.isHidden)
        XCTAssertFalse(controller.isAlwaysHiddenRevealed)
    }

    func testToggleFlipsAndNotifies() {
        controller.start(restoringHidden: false)
        controller.toggle()
        XCTAssertTrue(controller.isHidden)
        controller.toggle()
        XCTAssertFalse(controller.isHidden)
        XCTAssertEqual(changes, [true, false])
    }

    func testNeverHidesWhenToggleIsLeftOfSeparator() {
        controller.start(restoringHidden: false)
        host.toggleIsRightOfSeparator = false
        controller.hide()
        XCTAssertFalse(controller.isHidden)
        XCTAssertTrue(changes.isEmpty)
    }

    func testBadgeAndAppearanceUpdatesRender() {
        controller.start(restoringHidden: false)
        controller.setBadge(true)
        XCTAssertEqual(host.rendered.last?.hasBadge, true)
        controller.update(icon: .dot, showSeparator: false)
        XCTAssertEqual(host.rendered.last?.icon, .dot)
        XCTAssertEqual(host.rendered.last?.showSeparator, false)
        let count = host.rendered.count
        controller.setBadge(true) // no change, no re-render
        XCTAssertEqual(host.rendered.count, count)
    }
}

@MainActor
final class SectionAnimationSettingTests: XCTestCase {
    func testAnimationFlagReachesTheHost() {
        let host = FakeHost()
        let controller = SectionController(host: host, scheduler: FakeScheduler(), icon: .martini, showSeparator: true)
        controller.start(restoringHidden: false)
        XCTAssertEqual(host.rendered.last?.animates, true)
        controller.update(icon: .martini, showSeparator: true, animates: false)
        XCTAssertEqual(host.rendered.last?.animates, false)
    }

    func testOldSettingsFileDefaultsToAnimating() throws {
        let settings = try SettingsMigrator.migrate(Data(#"{"schemaVersion": 1}"#.utf8))
        XCTAssertTrue(settings.animateTransitions)
    }
}
