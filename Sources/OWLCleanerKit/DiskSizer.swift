import Foundation

/// Computes on-disk *allocated* size (blocks actually consumed, not logical
/// length), without following symlinks. Injected `FileManager` for testability.
public struct DiskSizer: Sendable {
    public init() {}

    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
    ]

    public func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Self.keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory == true { return directorySize(url) }
        return Self.fileBytes(values)
    }

    private func directorySize(_ dir: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: Array(Self.keys),
            options: [],
            errorHandler: { _, _ in true }  // skip unreadable entries, keep going
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Self.keys) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()  // never follow a symlinked directory
                continue
            }
            if values.isRegularFile == true {
                total += Self.fileBytes(values)
            }
        }
        return total
    }

    private static func fileBytes(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
    }
}
