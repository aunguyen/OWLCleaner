import Foundation

/// Reclaims regenerable system & application junk: user caches, logs, the
/// per-user temp directories, and (best-effort) user-deletable system caches.
public struct SystemJunkModule: CleanupModule {
    public let id = "system"
    public let title = "System & App Junk"
    public let systemImage = "macwindow"

    public static let userCaches = CleanupCategory(id: "system.caches", title: "User & App Caches", systemImage: "shippingbox")
    public static let logs = CleanupCategory(id: "system.logs", title: "Logs", systemImage: "doc.text")
    public static let temp = CleanupCategory(id: "system.temp", title: "Temporary Files", systemImage: "clock.arrow.circlepath")
    public static let systemCaches = CleanupCategory(id: "system.systemCaches", title: "System Caches", systemImage: "gearshape.2")

    public var categories: [CleanupCategory] { [Self.userCaches, Self.logs, Self.temp, Self.systemCaches] }

    private let scanner: DirectoryJunkScanner
    public var safeRoots: [URL] { scanner.roots.map(\.url) }

    public init(roots: [DirectoryJunkScanner.ScanRoot] = SystemJunkModule.standardRoots()) {
        scanner = DirectoryJunkScanner(moduleID: id, roots: roots, removalMode: .delete, defaultSelected: true)
    }

    public func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult {
        await scanner.scan(progress: progress)
    }

    /// The real on-disk locations scanned on this machine.
    public static func standardRoots() -> [DirectoryJunkScanner.ScanRoot] {
        let home = SystemPaths.home
        var roots: [DirectoryJunkScanner.ScanRoot] = [
            .init(url: home.appendingPathComponent("Library/Caches"), categoryID: userCaches.id),
            .init(url: home.appendingPathComponent("Library/Logs"), categoryID: logs.id),
        ]
        if let temp = SystemPaths.darwinUserDir(_CS_DARWIN_USER_TEMP_DIR) {
            roots.append(.init(url: temp, categoryID: Self.temp.id))
        }
        if let cache = SystemPaths.darwinUserDir(_CS_DARWIN_USER_CACHE_DIR) {
            roots.append(.init(url: cache, categoryID: Self.temp.id))
        }
        // Best-effort: user-deletable entries only; the rest are surfaced as
        // "needs elevated access" by the scanner's writability gate.
        roots.append(.init(url: URL(fileURLWithPath: "/Library/Caches"), categoryID: systemCaches.id))
        return roots
    }
}
