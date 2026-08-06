import SwiftUI
import CYAppCore

// MARK: - Badge

/// 小型角标/徽标，用于展示数量或状态。
public struct CYBadge: View {
    let title: String
    let backgroundColor: Color
    let textColor: Color

    public init(
        title: String,
        backgroundColor: Color = CYAppColor.error,
        textColor: Color = .white
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    public var body: some View {
        Text(title)
            .font(CYAppFont.caption)
            .fontWeight(.semibold)
            .foregroundColor(textColor)
            .padding(.horizontal, CYAppDimens.marginS)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - Tag

/// 可交互标签，支持选中/未选中状态。
public struct CYTag: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let unselectedColor: Color
    let textColor: Color
    let action: () -> Void

    public init(
        title: String,
        isSelected: Bool = false,
        selectedColor: Color = CYAppColor.primary,
        unselectedColor: Color = CYAppColor.secondaryBackground,
        textColor: Color = CYAppColor.textPrimary,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.unselectedColor = unselectedColor
        self.textColor = textColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(CYAppFont.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : textColor)
                .padding(.horizontal, CYAppDimens.marginM)
                .padding(.vertical, CYAppDimens.marginS)
                .background(isSelected ? selectedColor : unselectedColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Group

/// 一组标签，支持单选/多选布局。
public struct CYTagGroup<Data: RandomAccessCollection>: View where Data.Element: Hashable {
    let data: Data
    let selectedIDs: Set<Data.Element>
    let content: (Data.Element, Bool) -> CYTag

    public init(
        _ data: Data,
        selectedIDs: Set<Data.Element>,
        @ViewBuilder content: @escaping (Data.Element, Bool) -> CYTag
    ) {
        self.data = data
        self.selectedIDs = selectedIDs
        self.content = content
    }

    public var body: some View {
        FlowLayout(spacing: CYAppDimens.marginS) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, element in
                content(element, selectedIDs.contains(element))
            }
        }
    }
}

// MARK: - Flow Layout

/// 简单的流式布局容器，标签组常用。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let result = FlowResult(in: width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
