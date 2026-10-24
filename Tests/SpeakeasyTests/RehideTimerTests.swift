import XCTest
@testable import SpeakeasyKit

@MainActor
final class RehideTimerTests: XCTestCase {
    private var scheduler: FakeScheduler!
    private var menus: FakeMenus!
    private var expirations = 0
    private var timer: RehideTimer!

    override func setUp() async throws {
        scheduler = FakeScheduler()
        menus = FakeMenus()
        expirations = 0
        timer = RehideTimer(scheduler: scheduler, menus: menus) { [unowned self] in expirations += 1 }
        timer.delay = 10
    }

    func testFiresAfterDelay() {
        timer.arm()
        scheduler.advance(by: 9)
        XCTAssertEqual(expirations, 0)
        scheduler.advance(by: 1)
        XCTAssertEqual(expirations, 1)
    }

    func testOffNeverFires() {
        timer.delay = nil
        timer.arm()
        scheduler.advance(by: 120)
        XCTAssertEqual(expirations, 0)
    }

    func testDisarmCancels() {
        timer.arm()
        timer.disarm()
        scheduler.advance(by: 60)
        XCTAssertEqual(expirations, 0)
    }

    func testRearmRestartsCountdown() {
        timer.arm()
        scheduler.advance(by: 8)
        timer.arm()
        scheduler.advance(by: 8)
        XCTAssertEqual(expirations, 0)
        scheduler.advance(by: 2)
        XCTAssertEqual(expirations, 1)
    }

    func testOpenMenuPausesThenStartsFreshCountdown() {
        menus.isMenuOpen = true
        timer.arm()
        scheduler.advance(by: 30)
        XCTAssertEqual(expirations, 0, "must not collapse while a menu is open")

        menus.isMenuOpen = false
        scheduler.advance(by: 2) // paused poll notices the menu closed and re-arms
        XCTAssertEqual(expirations, 0)
        scheduler.advance(by: 10)
        XCTAssertEqual(expirations, 1)
    }
}
