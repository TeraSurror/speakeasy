import AppKit
import ApplicationServices

/// Reads every running app's status items through the Accessibility API. Needs the Accessibility permission;
/// without it this returns nothing and discovery falls back to window owners.
public struct AXExtrasMenuBarReader: ExtrasMenuBarReading {
    /// A hung app must not stall a refresh.
    static let messagingTimeout: Float = 0.2

    public init() {}

    public func extrasItems() -> [ExtrasMenuItem] {
        guard AXIsProcessTrusted() else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        var result: [ExtrasMenuItem] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited && app.processIdentifier != me {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
            var bar: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &bar) == .success, let bar else { continue }
            var children: CFTypeRef?
            AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &children)
            for child in (children as? [AXUIElement]) ?? [] {
                guard let frame = Self.frame(of: child), frame.width > 0 else { continue } // zero-sized entries are placeholders
                let label = Self.string(child, kAXTitleAttribute).flatMap { $0.isEmpty ? nil : $0 }
                    ?? Self.string(child, kAXDescriptionAttribute).flatMap { $0.isEmpty ? nil : $0 }
                result.append(ExtrasMenuItem(
                    pid: app.processIdentifier, appName: app.localizedName ?? "Unknown", bundleID: app.bundleIdentifier,
                    label: label, identifier: Self.string(child, kAXIdentifierAttribute), frame: frame))
            }
        }
        return result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin), AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }
}
