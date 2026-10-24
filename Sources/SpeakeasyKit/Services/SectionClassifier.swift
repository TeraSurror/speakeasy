import CoreGraphics

/// Assigns discovered items to sections by where they sit relative to Speakeasy's separators.
/// Pure, so it can be tested without real windows.
public enum SectionClassifier {
    /// - Parameter otherScreens: Displays other than the one holding Speakeasy's toggle. Items sitting on
    ///   them belong to those displays' menu bars and are dropped.
    public static func classify(
        _ items: [MenuBarItem], separators: SeparatorFrames, otherScreens: [CGRect] = []
    ) -> [MenuBarItem] {
        items.compactMap { item in
            let x = item.frame.midX
            if otherScreens.contains(where: { x >= $0.minX && x < $0.maxX }) { return nil }
            var item = item
            if x < separators.alwaysHiddenMinX {
                item.section = .alwaysHidden
            } else if x < separators.hiddenMinX {
                item.section = .hidden
            } else {
                item.section = .visible
            }
            return item
        }
    }
}
