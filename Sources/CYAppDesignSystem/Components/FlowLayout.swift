import SwiftUI

/// Wrapping layout with constrained measurement and semantic leading-to-trailing placement.
public struct CYFlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    @Environment(\.layoutDirection) private var layoutDirection

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = CYFlowGeometry.finiteWidth(proposal.width)
        let result = measure(subviews, width: width)
        return CGSize(width: width ?? result.width, height: result.height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = CYFlowGeometry.finiteWidth(bounds.width)
        let result = measure(subviews, width: width)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            let x = layoutDirection == .rightToLeft ? bounds.maxX - frame.maxX : bounds.minX + frame.minX
            subview.place(at: CGPoint(x: x, y: bounds.minY + frame.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: nil))
        }
    }

    private func measure(_ subviews: Subviews, width: CGFloat?) -> CYFlowGeometry {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        return CYFlowGeometry(sizes: sizes, maxWidth: width, spacing: spacing, lineSpacing: lineSpacing)
    }
}

// Shared by measuring and placement; finite results even for infinite proposals or invalid spacing.
struct CYFlowGeometry {
    var frames: [CGRect] = []
    var width: CGFloat = 0
    var height: CGFloat = 0

    static func finiteWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite else { return nil }
        return max(0, width)
    }

    init(sizes: [CGSize], maxWidth: CGFloat?, spacing: CGFloat, lineSpacing: CGFloat) {
        let limit = Self.finiteWidth(maxWidth) ?? .infinity
        let gap = spacing.isFinite ? max(0, spacing) : 0
        let rowGap = lineSpacing.isFinite ? max(0, lineSpacing) : 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var hasItem = false
        for raw in sizes {
            let size = CGSize(width: raw.width.isFinite ? max(0, raw.width) : 0,
                              height: raw.height.isFinite ? max(0, raw.height) : 0)
            if hasItem, x + size.width > limit {
                x = 0
                y += rowHeight + rowGap
                rowHeight = 0
                hasItem = false
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            width = max(width, x + size.width)
            rowHeight = max(rowHeight, size.height)
            height = y + rowHeight
            x += size.width + gap
            hasItem = true
        }
    }
}
