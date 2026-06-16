import Foundation

/// Finds large (and optionally old) files under a user-chosen folder. Unlike the
/// cache modules this never auto-selects anything and moves selections to the
/// Trash (recoverable) rather than deleting them — these are the user's own files.
public struct LargeOldFilesModule: CleanupModule {
    public let id = "largeold"
    public let title = "Large & Old Files"
    public let systemImage = "doc.text.magnifyingglass"

    public static let files = CleanupCategory(id: "largeold.files", title: "Large & Old Files", systemImage: "doc")
    public var categories: [CleanupCategory] { [Self.files] }

    public let searchRoot: URL?
    public let minBytes: Int64
    public let olderThanDays: Int?
    public let maxResults: Int

    public var safeRoots: [URL] { searchRoot.map { [$0] } ?? [] }

    public init(searchRoot: URL? = nil, minBytes: Int64 = 100 * 1024 * 1024,
                olderThanDays: Int? = nil, maxResults: Int = 300) {
        self.searchRoot = searchRoot
        self.minBytes = minBytes
        self.olderThanDays = olderThanDays
        self.maxResults = maxResults
    }

    /// Trash-only within the chosen folder, no cache denylist: these are user
    /// files moved recoverably to the Trash on explicit opt-in.
    public func cleaningGuard() -> SafetyGuard {
        SafetyGuard(safeRoots: safeRoots, denylist: [])
    }

    public func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult {
        guard let root = searchRoot else { return ModuleScanResult(moduleID: id, items: []) }

        let safetyGuard = SafetyGuard(safeRoots: [root], denylist: [])
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
            .contentModificationDateKey,
        ]
        let cutoff = olderThanDays.map { Date().addingTimeInterval(-Double($0) * 86_400) }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return ModuleScanResult(moduleID: id, items: []) }

        var items: [CleanupItem] = []
        while let object = enumerator.nextObject() {
            guard let url = object as? URL else { continue }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values.isRegularFile == true else { continue }

            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            guard size >= minBytes else { continue }
            if let cutoff, let modified = values.contentModificationDate, modified > cutoff { continue }

            guard case let .allowed(canonical) = safetyGuard.validate(url),
                  FileManager.default.isDeletableFile(atPath: canonical.path) else { continue }

            items.append(CleanupItem(
                url: canonical,
                displayName: url.lastPathComponent,
                sizeBytes: size,
                categoryID: Self.files.id,
                moduleID: id,
                removalMode: .trash,
                defaultSelected: false,
                note: "→ Trash"
            ))
        }

        // Largest first, capped to keep the list reviewable.
        items.sort { $0.sizeBytes > $1.sizeBytes }
        if items.count > maxResults { items = Array(items.prefix(maxResults)) }
        return ModuleScanResult(moduleID: id, items: items)
    }
}
