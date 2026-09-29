#if canImport(UIKit) && canImport(Photos)
import SwiftUI
import Photos
import CYAppDesignSystem

// MARK: - 全屏图片预览
//
// 仿微信预览逻辑：
// - 左右滑动浏览所有图片
// - 底部右侧「选择」按钮，可在预览中选中/取消
// - 底部左侧「原图」开关（可选）
// - 右上角「完成(n)」按钮

/// 全屏图片预览视图
struct CYPhotoPreviewView: View {

    let assets: [PHAsset]
    @Binding var currentIndex: Int
    @Bindable var selectionManager: CYMediaSelectionManager
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                        CYPreviewCell(asset: asset)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(.white)
                    .accessibilityLabel("cancel".cyLocalized)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Text(doneTitle)
                            .font(CYAppFont.button)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectionManager.hasSelection
                                    ? CYAppColor.primary
                                    : Color.white.opacity(0.2)
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(!selectionManager.hasSelection)
                    .tint(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 底部栏

    private var bottomBar: some View {
        HStack {
            // 原图开关
            if selectionManager.allowsOriginal {
                Toggle(isOn: Binding(
                    get: { selectionManager.sendOriginal },
                    set: { selectionManager.sendOriginal = $0 }
                )) {
                    Text("media_original".cyLocalized)
                        .font(CYAppFont.bodyMedium)
                        .foregroundStyle(.white)
                }
                .tint(CYAppColor.primary)
            }

            Spacer()

            // 选择按钮
            if currentIndex < assets.count {
                let asset = assets[currentIndex]
                let isSelected = selectionManager.isSelected(asset)

                Button {
                    if !selectionManager.toggle(asset) {
                        // 达到上限，震动反馈
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                        Text("media_select".cyLocalized)
                            .font(CYAppFont.bodyMedium)
                    }
                    .foregroundStyle(.white)
                }
                .opacity(selectionManager.canSelectMore || isSelected ? 1.0 : 0.4)
            }
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.vertical, CYAppDimens.marginS)
        .background(.ultraThinMaterial)
    }

    private var doneTitle: String {
        selectionManager.hasSelection
            ? String(format: "media_done_count".cyLocalized, selectionManager.selectedCount)
            : "media_done".cyLocalized
    }
}

// MARK: - 预览单元

struct CYPreviewCell: View {

    let asset: PHAsset
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .pinchToZoom()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: asset.localIdentifier) {
            if image == nil {
                isLoading = true
                image = await CYPhotoAssetLoader.shared.loadFullImage(for: asset)
                isLoading = false
            }
        }
    }
}

// MARK: - 双击缩放修饰

private struct PinchToZoom: ViewModifier {

    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale * gestureScale)
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        withAnimation(.spring(duration: 0.3)) {
                            scale = min(max(scale * value, 1.0), 4.0)
                            if scale < 1.0 { scale = 1.0 }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    scale = scale > 1.0 ? 1.0 : 2.0
                }
            }
    }
}

private extension View {
    func pinchToZoom() -> some View {
        modifier(PinchToZoom())
    }
}
#endif
