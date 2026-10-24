import ApplicationServices
import CoreGraphics

public struct SystemAccessibilityPermission: AccessibilityPermission {
    public init() {}

    public var isTrusted: Bool { AXIsProcessTrusted() }

    public func requestPrompt() {
        // The literal avoids touching the C global `kAXTrustedCheckOptionPrompt` under strict concurrency.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}

public struct CGEventPoster: EventPosting {
    public init() {}

    @MainActor
    public var cursorLocation: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    @MainActor
    public func post(_ event: SyntheticMouseEvent) {
        let type: CGEventType = switch event.kind {
        case .move: .mouseMoved
        case .down: .leftMouseDown
        case .dragged: .leftMouseDragged
        case .up: .leftMouseUp
        }
        guard let cg = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: event.location, mouseButton: .left) else { return }
        cg.flags = event.command ? .maskCommand : []
        cg.post(tap: .cghidEventTap)
    }

    @MainActor
    public func warpCursor(to location: CGPoint) {
        CGWarpMouseCursorPosition(location)
    }
}
