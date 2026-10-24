import XCTest
@testable import SpeakeasyKit

final class SettingsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileGivesDefaults() {
        let store = JSONSettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        XCTAssertEqual(store.load(), Settings())
    }

    func testRoundTrip() {
        let store = JSONSettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        var settings = Settings()
        settings.rehideDelay = 25
        settings.toggleIcon = .dot
        settings.isHidden = false
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testUnversionedFileMigratesAndKeepsValues() throws {
        let data = Data(#"{"rehideDelay": 30, "toggleIcon": "chevron"}"#.utf8)
        let settings = try SettingsMigrator.migrate(data)
        XCTAssertEqual(settings.schemaVersion, Settings.currentSchemaVersion)
        XCTAssertEqual(settings.rehideDelay, 30)
        XCTAssertEqual(settings.toggleIcon, .chevron)
        XCTAssertTrue(settings.rehideOnClickOutside)
    }

    func testDelayIsClampedToRange() throws {
        XCTAssertEqual(try SettingsMigrator.migrate(Data(#"{"rehideDelay": 500}"#.utf8)).rehideDelay, 60)
        XCTAssertEqual(try SettingsMigrator.migrate(Data(#"{"rehideDelay": 0}"#.utf8)).rehideDelay, 2)
    }

    func testCorruptFileIsBackedUpAndReset() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("settings.json")
        try Data("not json".utf8).write(to: url)
        let store = JSONSettingsStore(fileURL: url)

        XCTAssertEqual(store.load(), Settings())
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("settings.corrupt-") })
    }
}
