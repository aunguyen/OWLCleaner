import Foundation

/// A throwaway directory tree under the system temp dir for exercising the
/// SafetyGuard and modules against *real* files, symlinks, and traversal — the
/// catastrophic-risk surface we must not get wrong. Cleaned up on `deinit`.
final class TempSandbox {
    let root: URL
    private let fm = FileManager.default

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("owlcleaner-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? fm.removeItem(at: root)
    }

    /// Create a directory (and intermediates) at a relative path under the sandbox.
    @discardableResult
    func makeDir(_ relativePath: String) -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Create a file of `bytes` length at a relative path (intermediates created).
    @discardableResult
    func makeFile(_ relativePath: String, bytes: Int = 0) -> URL {
        let url = root.appendingPathComponent(relativePath)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: url.path, contents: Data(count: bytes))
        return url
    }

    /// Create a symlink at `relativePath` pointing to an absolute `target`.
    @discardableResult
    func makeSymlink(_ relativePath: String, to target: URL) -> URL {
        let url = root.appendingPathComponent(relativePath)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.createSymbolicLink(at: url, withDestinationURL: target)
        return url
    }

    /// An absolute URL inside the sandbox without creating anything.
    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }
}
