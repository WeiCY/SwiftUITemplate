import Foundation

extension FileManager {

    // MARK: - Common Paths

    public var documentsDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public var cachesDirectory: URL {
        urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    public var tempDirectory: URL {
        temporaryDirectory
    }

    public var applicationSupportDirectory: URL {
        urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    // MARK: - File Operations

    public func fileSize(at url: URL) -> UInt64? {
        try? attributesOfItem(atPath: url.path)[.size] as? UInt64
    }

    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    public func createDirectoryIfNeeded(at url: URL) throws {
        guard !fileExists(atPath: url.path) else { return }
        try createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func clearDirectory(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        let contents = try contentsOfDirectory(atPath: url.path)
        for item in contents {
            try removeItem(at: url.appendingPathComponent(item))
        }
    }

    // MARK: - Disk Space

    public var availableDiskSpace: UInt64? {
        guard let attrs = try? attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? UInt64 else { return nil }
        return free
    }

    public var totalDiskSpace: UInt64? {
        guard let attrs = try? attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = attrs[.systemSize] as? UInt64 else { return nil }
        return total
    }

    public var availableDiskSpaceFormatted: String {
        guard let bytes = availableDiskSpace else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: - Directory Size

    public func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }

    public func directorySizeFormatted(at url: URL) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(directorySize(at: url)), countStyle: .file)
    }
}
