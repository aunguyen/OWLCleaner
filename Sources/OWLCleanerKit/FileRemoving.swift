import Foundation

/// The two ways the Cleaner can remove something. Injected so deletion logic can
/// be unit-tested without touching the real filesystem or the user's Trash.
public protocol FileRemoving: Sendable {
    /// Permanently remove the item (the link itself for a symlink — never its target).
    func removeItem(at url: URL) throws
    /// Move the item to the Trash (recoverable).
    func trashItem(at url: URL) throws
}

/// Production implementation backed by `FileManager`.
public struct SystemFileRemover: FileRemoving {
    public init() {}

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func trashItem(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
