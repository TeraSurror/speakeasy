import Foundation

public enum ToggleIcon: String, Codable, CaseIterable, Identifiable, Sendable {
    case martini, chevron, dot

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .martini: "Martini glass"
        case .chevron: "Chevron"
        case .dot: "Dot"
        }
    }

    /// There is no martini SF Symbol; `wineglass` is the closest stemmed-glass symbol.
    public func symbolName(isHidden: Bool) -> String {
        switch self {
        case .martini: isHidden ? "wineglass" : "wineglass.fill"
        case .chevron: isHidden ? "chevron.left" : "chevron.right"
        case .dot: isHidden ? "circle" : "circle.fill"
        }
    }
}

/// Hotkeys are stored by KeyboardShortcuts in UserDefaults rather than in this file.
public struct Settings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let rehideDelayRange: ClosedRange<Double> = 2...60

    public var schemaVersion = Settings.currentSchemaVersion
    public var rehideEnabled = true
    public var rehideDelay: Double = 10
    public var rehideOnClickOutside = true
    public var toggleIcon: ToggleIcon = .martini
    public var showSeparator = true
    public var animateTransitions = true
    /// Whether the hidden section was collapsed when the app last ran.
    public var isHidden = true
    public var onboardingCompleted = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        rehideEnabled = try c.decodeIfPresent(Bool.self, forKey: .rehideEnabled) ?? d.rehideEnabled
        let delay = try c.decodeIfPresent(Double.self, forKey: .rehideDelay) ?? d.rehideDelay
        rehideDelay = min(max(delay, Self.rehideDelayRange.lowerBound), Self.rehideDelayRange.upperBound)
        rehideOnClickOutside = try c.decodeIfPresent(Bool.self, forKey: .rehideOnClickOutside) ?? d.rehideOnClickOutside
        toggleIcon = try c.decodeIfPresent(ToggleIcon.self, forKey: .toggleIcon) ?? d.toggleIcon
        showSeparator = try c.decodeIfPresent(Bool.self, forKey: .showSeparator) ?? d.showSeparator
        animateTransitions = try c.decodeIfPresent(Bool.self, forKey: .animateTransitions) ?? d.animateTransitions
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? d.isHidden
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? d.onboardingCompleted
    }
}
