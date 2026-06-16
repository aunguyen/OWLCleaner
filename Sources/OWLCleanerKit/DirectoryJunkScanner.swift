import Foundation

/// Reusable scanner: treats each immediate child of every configured root as a
/// cleanable item. The root itself is never an item (SafetyGuard enforces this).
/// System / Trash / Developer modules all configure one of these.
public struct DirectoryJunkScanner: Sendable {

    public struct ScanRoot: Sendable, Equatable {
        public let url: URL
        public let categoryID: String
        public init(url: URL, categoryID: String) {
            self.url = url
            self.categoryID = categoryID
        }
    }

    public let moduleID: String
    public let roots: [ScanRoot]
    public let removalMode: RemovalMode
    public let defaultSelected: Bool

    private let sizer = DiskSizer()
    private let safetyGuard: SafetyGuard

    public init(moduleID: String, roots: [ScanRoot], removalMode: RemovalMode, defaultSelected: Bool) {
        self.moduleID = moduleID
        self.roots = roots
        self.removalMode = removalMode
        self.defaultSelected = defaultSelected
        self.safetyGuard = SafetyGuard(safeRoots: roots.map(\.url))
    }

    public func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult {
        let fileManager = FileManager.default
        var items: [CleanupItem] = []
        var skipped: [SkippedPath] = []
        let total = max(roots.count, 1)

        for (index, root) in roots.enumerated() {
            let children = (try? fileManager.contentsOfDirectory(
                at: root.url,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []

            for child in children {
                switch safetyGuard.validate(child) {
                case let .allowed(url):
                    // Scope boundary: anything we can't actually delete (root-owned
                    // system caches, etc.) is surfaced as needing elevated access —
                    // never offered as a cleanable item.
                    guard fileManager.isDeletableFile(atPath: url.path) else {
                        skipped.append(SkippedPath(url: url, reason: .needsElevatedAccess))
                        continue
                    }
                    let size = sizer.allocatedSize(of: url)
                    guard size > 0 else { continue }  // skip empty entries — only noise
                    items.append(CleanupItem(
                        url: url,
                        sizeBytes: size,
                        categoryID: root.categoryID,
                        moduleID: moduleID,
                        removalMode: removalMode,
                        defaultSelected: defaultSelected
                    ))
                case let .rejected(rejection):
                    let reason: SkipReason = rejection == .denylisted ? .needsElevatedAccess : .outsideSafeRoot
                    skipped.append(SkippedPath(url: child, reason: reason))
                }
            }
            progress(Double(index + 1) / Double(total))
        }

        return ModuleScanResult(moduleID: moduleID, items: items, skipped: skipped)
    }
}
