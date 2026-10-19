import SwiftUI
import CYAppCore
import CYAppUI
import CYAppDesignSystem
#if canImport(UIKit) && canImport(PhotosUI)
import PhotosUI
import AVKit

struct MediaExample: View {
    @State private var status = "尚未选择 / No selection"
    @State private var permission: CYPermissionStatus = .notDetermined
    @State private var items: [CYMediaItem] = []
    @State private var image: UIImage?
    @State private var preview = false
    @State private var loading = false
    @State private var selectionID = UUID()
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Text(status).accessibilityIdentifier("media.status")
            Button("申请相册权限 / Request library access") {
                Task {
                    permission = await CYPermissionManager.shared.request(.photoLibrary)
                    status = "相册权限 / Library: \(permission.rawValue)"
                }
            }
            if permission == .denied || permission == .restricted {
                Text("请在系统设置中允许访问；受限设备可能需要管理员调整。")
                Button("打开设置 / Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            CYMediaPicker(style: .grid, maxSelection: 3, allowsCamera: true,
                          onCancel: { status = "已取消，保留原选择 / Cancelled" },
                          onImportFailure: { status = "导入失败，请重选 / Import failed" }) { selected in
                items = selected
                selectionID = UUID()
            } label: { Label("网格选择与预览 / Grid picker", systemImage: "photo.on.rectangle") }
            CYMediaPicker(style: .system, source: .album, maxSelection: 1, filter: .videos,
                          onImportFailure: { status = "视频导入失败，请重选 / Video import failed" }) { selected in
                items = selected
                selectionID = UUID()
            } label: { Label("导入视频 / Import video", systemImage: "video") }
            if loading { ProgressView("加载中 / Loading") }
            if let image {
                Button { preview = true } label: {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                }
                .accessibilityLabel("预览所选图片 / Preview selected image")
            }
            if let url = items.first?.videoURL {
                VideoPlayer(player: AVPlayer(url: url)).frame(height: 220)
                Text("当前媒体项持有导入副本；清除选择后释放。长期保存应复制到自己的目录。")
            }
            Button("清除选择并释放文件 / Release selection") { items = []; image = nil; selectionID = UUID() }
            Button("模拟加载失败 / Simulate failure") { status = "加载失败，请重新选择 / Load failed, select again" }
        }
        .navigationTitle("媒体 / Media")
        .task(id: selectionID) {
            let id = selectionID
            loading = true
            defer { if selectionID == id { loading = false } }
            image = nil
            guard let item = items.first else { return }
            if !item.isVideo {
                let loaded = await item.loadImage()
                guard !Task.isCancelled else { return }
                image = loaded
                status = loaded == nil ? "加载失败，请重新选择 / Load failed" : "加载成功 / Loaded"
            } else { status = "视频导入完成 / Video imported" }
        }
        .sheet(isPresented: $preview) {
            if let image {
                VStack {
                    Image(uiImage: image).resizable().scaledToFit()
                    Button("关闭预览 / Close preview") { preview = false }
                }.padding()
            }
        }
    }
}
#else
struct MediaExample: View {
    var body: some View { Text("媒体选择需要 iOS / Media picking requires iOS") }
}
#endif
