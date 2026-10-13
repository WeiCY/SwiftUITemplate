#if canImport(UIKit) && canImport(PhotosUI)
import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// 保持导入视频的临时文件存活；最后一个媒体项释放后清理副本。
final class CYMediaVideoStorage: Hashable, Sendable {
    let url: URL
    private let ownsFile: Bool

    init(url: URL, ownsFile: Bool = false) {
        self.url = url
        self.ownsFile = ownsFile
    }

    static func == (lhs: CYMediaVideoStorage, rhs: CYMediaVideoStorage) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    deinit {
        if ownsFile { try? FileManager.default.removeItem(at: url) }
    }
}

struct CYMediaVideoFile: Transferable, Sendable {
    let storage: CYMediaVideoStorage

    /// PhotosPicker 提供的文件只在 importing 闭包期间有效，必须先复制。
    static func copy(from source: URL) throws -> CYMediaVideoFile {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        try FileManager.default.copyItem(at: source, to: destination)
        return CYMediaVideoFile(storage: CYMediaVideoStorage(url: destination, ownsFile: true))
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copy(from: received.file)
        }
    }
}
#endif
