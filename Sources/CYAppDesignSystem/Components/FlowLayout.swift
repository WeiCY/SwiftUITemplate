import SwiftUI

// MARK: - 流式换行布局

/// 流式换行布局：子视图按行排列，超出可用宽度时自动换行。
///
/// 适合标签云、筛选 Chip、话题列表等需要自动换行的场景。
///
/// ```swift
/// CYFlowLayout(spacing: 8) {
///     ForEach(tags) { tag in
///         CYTag(title: tag.name)
///     }
/// }
/// ```
public struct CYFlowLayout: Layout {

    /// 同一行内子视图的水平间距
    public var spacing: CGFloat
    /// 行与行之间的垂直间距（默认等于 `spacing`）
    public var lineSpacing: CGFloat

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = FlowResult(in: maxWidth, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)
        // 宽度已知时填满可用宽度（利于对齐）；宽度未指定时返回内容固有宽度，
        // 避免向父布局返回无限宽（此前 bug）。
        let width = proposal.width ?? result.intrinsicWidth
        return CGSize(width: width, height: result.height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    // MARK: - 布局计算

    private struct FlowResult {
        var positions: [CGPoint] = []
        /// 内容固有宽度（最长一行的实际宽度）
        var intrinsicWidth: CGFloat = 0
        /// 内容总高度
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat, lineSpacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxLineWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x > 0, x + size.width > maxWidth {
                    maxLineWidth = max(maxLineWidth, x - spacing)
                    x = 0
                    y += lineHeight + lineSpacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            maxLineWidth = max(maxLineWidth, max(0, x - spacing))
            self.intrinsicWidth = maxLineWidth
            self.height = y + lineHeight
        }
    }
}
