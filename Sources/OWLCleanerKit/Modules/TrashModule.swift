import Foundation

/// Empties the user's Trash plus per-volume trashes. There is no public
/// "empty Trash" API, so each top-level entry in every trash directory is
/// removed individually (skipping anything not deletable).
public struct TrashModule: CleanupModule {
    public let id = "trash"
    public let title = "Trash"
    public let systemImage = "trash"

    public static let bins = CleanupCategory(id: "trash.bins", title: "Trash", systemImage: "trash")
    public var categories: [CleanupCategory] { [Self.bins] }

    private let scanner: DirectoryJunkScanner
    public var safeRoots: [URL] { scanner.roots.map(\.url) }

    public init(roots: [DirectoryJunkScanner.ScanRoot] = TrashModule.standardRoots()) {
        scanner = DirectoryJunkScanner(moduleID: id, roots: roots, removalMode: .delete, defaultSelected: true)
    }

    public func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult {
        await scanner.scan(progress: progress)
    }

    public static func standardRoots() -> [DirectoryJunkScanner.ScanRoot] {
        var roots: [DirectoryJunkScanner.ScanRoot] = [
            .init(url: SystemPaths.home.appendingPathComponent(".Trash"), categoryID: bins.id)
        ]
        // Per-volume trashes: /Volumes/<name>/.Trashes/<uid>
        let uid = String(getuid())
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        )) ?? []
        for volume in volumes {
            let trash = volume.appendingPathComponent(".Trashes").appendingPathComponent(uid)
            roots.append(.init(url: trash, categoryID: bins.id))
        }
        return roots
    }
}
