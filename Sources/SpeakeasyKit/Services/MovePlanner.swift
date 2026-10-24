import CoreGraphics

public struct DragPlan: Equatable, Sendable {
    public var start: CGPoint
    public var end: CGPoint
}

/// Works out where to grab an item and where to drop it for a given target section.
/// Pure, so it is tested without real windows. All sections must be revealed when the plan is used.
public enum MovePlanner {
    /// Items narrower than this can't be reliably grabbed.
    static let minimumGrabWidth: CGFloat = 4

    public static func plan(for item: MenuBarItem, to target: Section, separators: SeparatorFrames, notches: [CGRect] = []) -> DragPlan? {
        guard let start = grabPoint(for: item, avoiding: notches) else { return nil }
        let x: CGFloat
        switch target {
        case .alwaysHidden: x = separators.alwaysHiddenMinX - 1
        case .hidden: x = separators.hiddenMinX - 1
        case .visible: x = min(separators.hiddenMaxX + 2, separators.toggleMidX - 1)
        }
        return DragPlan(start: start, end: CGPoint(x: x, y: item.frame.midY))
    }

    /// The middle of the widest part of the item that isn't covered by a notch, or nil if all of it is.
    static func grabPoint(for item: MenuBarItem, avoiding notches: [CGRect]) -> CGPoint? {
        var segments = [(item.frame.minX, item.frame.maxX)]
        for notch in notches where item.frame.intersects(notch) {
            segments = segments.flatMap { s in
                [(s.0, min(s.1, notch.minX)), (max(s.0, notch.maxX), s.1)].filter { $0.1 - $0.0 > 0 }
            }
        }
        guard let best = segments.max(by: { $0.1 - $0.0 < $1.1 - $1.0 }), best.1 - best.0 >= minimumGrabWidth else { return nil }
        return CGPoint(x: (best.0 + best.1) / 2, y: item.frame.midY)
    }
}
