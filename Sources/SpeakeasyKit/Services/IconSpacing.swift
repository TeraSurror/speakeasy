import Foundation

/// Writes `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` to the current-host global domain,
/// the same place as `defaults -currentHost write -g NSStatusItemSpacing -int N`.
public struct DefaultsIconSpacing: IconSpacingControlling {
    /// Spacing values the slider offers. macOS uses roughly the top of the range when nothing is set.
    public static let range = 2...16
    public static let systemDefault = 16

    static let spacingKey = "NSStatusItemSpacing"
    static let paddingKey = "NSStatusItemSelectionPadding"

    private let applicationID: CFString

    public init(applicationID: CFString = kCFPreferencesAnyApplication) {
        self.applicationID = applicationID
    }

    public var current: Int? {
        guard let value = CFPreferencesCopyValue(
            Self.spacingKey as CFString, applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? Int else { return nil }
        return value
    }

    public func apply(_ value: Int) {
        let clamped = min(max(value, Self.range.lowerBound), Self.range.upperBound) as CFNumber
        // Spacing and padding move together so the slider has one meaning.
        for key in [Self.spacingKey, Self.paddingKey] {
            CFPreferencesSetValue(key as CFString, clamped, applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        }
        CFPreferencesSynchronize(applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    public func reset() {
        for key in [Self.spacingKey, Self.paddingKey] {
            CFPreferencesSetValue(key as CFString, nil, applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        }
        CFPreferencesSynchronize(applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// On macOS 26 status items are hosted by Control Center; SystemUIServer covers older releases.
    public func restartMenuBar() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["ControlCenter", "SystemUIServer"]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}
