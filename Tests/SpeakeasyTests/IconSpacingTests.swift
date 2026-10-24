import XCTest
@testable import SpeakeasyKit

final class DefaultsIconSpacingTests: XCTestCase {
    // A private application ID so the real global domain is never touched.
    private let spacing = DefaultsIconSpacing(applicationID: "com.harshshelar.speakeasy.tests.spacing" as CFString)

    override func tearDown() {
        spacing.reset()
    }

    func testUnsetMeansSystemDefault() {
        spacing.reset()
        XCTAssertNil(spacing.current)
    }

    func testApplyWritesBothKeys() {
        let id = "com.harshshelar.speakeasy.tests.spacing" as CFString
        spacing.apply(8)
        XCTAssertEqual(spacing.current, 8)
        let padding = CFPreferencesCopyValue("NSStatusItemSelectionPadding" as CFString, id, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? Int
        XCTAssertEqual(padding, 8)
    }

    func testApplyClampsToTheSliderRange() {
        spacing.apply(99)
        XCTAssertEqual(spacing.current, DefaultsIconSpacing.range.upperBound)
        spacing.apply(-3)
        XCTAssertEqual(spacing.current, DefaultsIconSpacing.range.lowerBound)
    }

    func testResetDeletesBothOverrides() {
        let id = "com.harshshelar.speakeasy.tests.spacing" as CFString
        spacing.apply(6)
        spacing.reset()
        XCTAssertNil(spacing.current)
        XCTAssertNil(CFPreferencesCopyValue("NSStatusItemSelectionPadding" as CFString, id, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost))
    }
}

private final class FakeSpacing: IconSpacingControlling {
    var current: Int?
    var restarts = 0
    var restartError: Error?
    func apply(_ value: Int) { current = value }
    func reset() { current = nil }
    func restartMenuBar() throws {
        if let restartError { throw restartError }
        restarts += 1
    }
}

private struct MemoryStore: SettingsPersisting {
    func load() -> Settings { Settings() }
    func save(_ settings: Settings) {}
}

private struct NoLogin: LoginItemControlling {
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

@MainActor
private struct NoHotkeys: HotkeyRegistering, HotkeyConflictChecking {
    func setHandler(for action: HotkeyAction, _ handler: @escaping @MainActor () -> Void) {}
    func combo(for action: HotkeyAction) -> KeyCombo? { nil }
    nonisolated func conflict(for combo: KeyCombo) -> String? { nil }
}

@MainActor
final class IconSpacingModelTests: XCTestCase {
    private var control: FakeSpacing!
    private var model: AppModel!

    override func setUp() async throws {
        control = FakeSpacing()
        let hotkeys = NoHotkeys()
        model = AppModel(store: MemoryStore(), loginItems: NoLogin(), hotkeys: hotkeys, conflicts: hotkeys)
        model.spacingControl = control
    }

    func testStartsFromTheCurrentOverride() {
        control.current = 10
        model.spacingControl = control
        XCTAssertEqual(model.iconSpacing, 10)
        XCTAssertFalse(model.iconSpacingNeedsRestart)
    }

    func testSettingSpacingAppliesAndAsksForARestart() {
        model.setIconSpacing(8)
        XCTAssertEqual(control.current, 8)
        XCTAssertEqual(model.iconSpacing, 8)
        XCTAssertTrue(model.iconSpacingNeedsRestart)
    }

    func testResetDeletesTheOverride() {
        model.setIconSpacing(8)
        model.resetIconSpacing()
        XCTAssertNil(control.current)
        XCTAssertNil(model.iconSpacing)
        XCTAssertTrue(model.iconSpacingNeedsRestart, "going back to the default also needs a restart to show")
    }

    func testResetWithNoOverrideChangesNothing() {
        model.resetIconSpacing()
        XCTAssertFalse(model.iconSpacingNeedsRestart)
    }

    func testRestartClearsTheNotice() {
        model.setIconSpacing(8)
        model.restartMenuBar()
        XCTAssertEqual(control.restarts, 1)
        XCTAssertFalse(model.iconSpacingNeedsRestart)
    }

    func testRestartFailureIsReportedAndKeepsTheNotice() {
        struct Boom: Error {}
        model.setIconSpacing(8)
        control.restartError = Boom()
        model.restartMenuBar()
        XCTAssertNotNil(model.iconSpacingError)
        XCTAssertTrue(model.iconSpacingNeedsRestart)
    }
}
