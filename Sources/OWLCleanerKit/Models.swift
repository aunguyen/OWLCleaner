import Foundation

/// How a cleanup item should be removed.
///
/// Regenerable junk (caches, logs, temp) is hard-deleted. User files surfaced by
/// the Large & Old finder are moved to the Trash so they stay recoverable.
public enum RemovalMode: String, Sendable, Equatable, Codable {
    case delete
    case trash
}

/// A user-facing grouping of cleanable items within a module.
public struct CleanupCategory: Sendable, Equatable, Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

/// A single cleanable thing: a file or top-level directory the user can review and remove.
public struct CleanupItem: Sendable, Equatable, Identifiable, Hashable, Codable {
    public let id: String
    public let url: URL
    public let displayName: String
    public let sizeBytes: Int64
    public let categoryID: String
    public let moduleID: String
    public let removalMode: RemovalMode
    /// Items the user must opt *in* to (e.g. Large & Old files) start deselected.
    public let defaultSelected: Bool
    /// Optional caution shown in the UI (never auto-selected when set).
    public let note: String?

    public init(
        id: String? = nil,
        url: URL,
        displayName: String? = nil,
        sizeBytes: Int64,
        categoryID: String,
        moduleID: String,
        removalMode: RemovalMode = .delete,
        defaultSelected: Bool = true,
        note: String? = nil
    ) {
        self.id = id ?? url.path
        self.url = url
        self.displayName = displayName ?? url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.categoryID = categoryID
        self.moduleID = moduleID
        self.removalMode = removalMode
        self.defaultSelected = defaultSelected
        self.note = note
    }
}

/// Why a candidate path was not offered for cleaning.
public enum SkipReason: String, Sendable, Equatable, Codable {
    case permissionDenied
    case outsideSafeRoot
    case needsElevatedAccess
    case unreadable
}

public struct SkippedPath: Sendable, Equatable, Hashable, Codable {
    public let url: URL
    public let reason: SkipReason

    public init(url: URL, reason: SkipReason) {
        self.url = url
        self.reason = reason
    }
}

/// The result of scanning one module.
public struct ModuleScanResult: Sendable, Equatable {
    public let moduleID: String
    public let items: [CleanupItem]
    public let skipped: [SkippedPath]

    public init(moduleID: String, items: [CleanupItem], skipped: [SkippedPath] = []) {
        self.moduleID = moduleID
        self.items = items
        self.skipped = skipped
    }

    public var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
}

/// A deletion that failed or was blocked, with a human-readable reason.
public struct CleanFailure: Sendable, Equatable, Hashable {
    public let url: URL
    public let reason: String

    public init(url: URL, reason: String) {
        self.url = url
        self.reason = reason
    }
}

/// The outcome of a clean run.
public struct CleanOutcome: Sendable, Equatable {
    public var removed: [URL]
    public var freedBytes: Int64
    public var failures: [CleanFailure]

    public init(removed: [URL] = [], freedBytes: Int64 = 0, failures: [CleanFailure] = []) {
        self.removed = removed
        self.freedBytes = freedBytes
        self.failures = failures
    }

    public var removedCount: Int { removed.count }
}

/// A cleanup module scans a known-safe area and reports what it found.
///
/// Scanning runs off the main actor; the progress closure and all result types
/// are `Sendable` so results cross actor boundaries cleanly under Swift 6.
public protocol CleanupModule: Sendable {
    var id: String { get }
    var title: String { get }
    var systemImage: String { get }
    var categories: [CleanupCategory] { get }
    func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult
}
