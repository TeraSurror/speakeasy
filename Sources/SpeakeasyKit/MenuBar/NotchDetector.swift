import Foundation

/// Finds status items that do not fit in the usable menu bar areas on either side of the notch.
public struct NotchDetector {
    public init() {}

    public func overflowingItems(in items: [MenuBarItem], screens: [ScreenInfo]) -> [MenuBarItem] {
        var result: [MenuBarItem] = []
        let tolerance: CGFloat = 4 // real windows overhang the screen edge by a point or two

        for screen in screens {
            guard let notch = screen.notchRect else { continue } // no notch: feature stays inactive
            let frame = screen.cgFrame
            let left = CGRect(x: frame.minX, y: frame.minY, width: notch.minX - frame.minX, height: screen.topInset)
            let right = CGRect(x: notch.maxX, y: frame.minY, width: frame.maxX - notch.maxX, height: screen.topInset)

            for item in items where !result.contains(where: { $0.id == item.id }) {
                let f = item.frame
                guard f.midY >= frame.minY, f.midY <= frame.minY + screen.topInset else { continue }
                // Items that start off the left edge were pushed away on purpose by the separator.
                guard f.minX >= frame.minX - tolerance, f.minX < frame.maxX - tolerance else { continue }
                let inLeft = f.minX >= left.minX - tolerance && f.maxX <= left.maxX + tolerance
                let inRight = f.minX >= right.minX - tolerance && f.maxX <= right.maxX + tolerance
                if !inLeft && !inRight {
                    result.append(item)
                }
            }
        }
        return result
    }
}
