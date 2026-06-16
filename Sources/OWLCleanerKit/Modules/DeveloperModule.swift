import Foundation

/// Reclaims developer junk: Xcode DerivedData & device support, simulator caches,
/// and package-manager caches (npm, Yarn, pip, Homebrew, CocoaPods, Gradle).
/// All of these are regenerated on demand, so they are hard-deleted.
public struct DeveloperModule: CleanupModule {
    public let id = "developer"
    public let title = "Developer"
    public let systemImage = "hammer"

    public static let derivedData = CleanupCategory(id: "dev.derivedData", title: "Xcode DerivedData", systemImage: "cube.box")
    public static let deviceSupport = CleanupCategory(id: "dev.deviceSupport", title: "Device Support", systemImage: "iphone")
    public static let simulators = CleanupCategory(id: "dev.simulators", title: "Simulator Caches", systemImage: "apps.iphone")
    public static let packages = CleanupCategory(id: "dev.packages", title: "Package Manager Caches", systemImage: "shippingbox.circle")

    public var categories: [CleanupCategory] { [Self.derivedData, Self.deviceSupport, Self.simulators, Self.packages] }

    private let scanner: DirectoryJunkScanner
    public var safeRoots: [URL] { scanner.roots.map(\.url) }

    public init(roots: [DirectoryJunkScanner.ScanRoot] = DeveloperModule.standardRoots()) {
        scanner = DirectoryJunkScanner(moduleID: id, roots: roots, removalMode: .delete, defaultSelected: true)
    }

    public func scan(progress: @Sendable @escaping (Double) -> Void) async -> ModuleScanResult {
        await scanner.scan(progress: progress)
    }

    public static func standardRoots() -> [DirectoryJunkScanner.ScanRoot] {
        let home = SystemPaths.home
        func root(_ path: String, _ category: CleanupCategory) -> DirectoryJunkScanner.ScanRoot {
            .init(url: home.appendingPathComponent(path), categoryID: category.id)
        }
        return [
            root("Library/Developer/Xcode/DerivedData", derivedData),
            root("Library/Developer/Xcode/iOS DeviceSupport", deviceSupport),
            root("Library/Developer/Xcode/watchOS DeviceSupport", deviceSupport),
            root("Library/Developer/Xcode/tvOS DeviceSupport", deviceSupport),
            root("Library/Developer/CoreSimulator/Caches", simulators),
            root(".npm/_cacache", packages),
            root("Library/Caches/Yarn", packages),
            root("Library/Caches/pip", packages),
            root("Library/Caches/Homebrew", packages),
            root("Library/Caches/CocoaPods", packages),
            root(".gradle/caches", packages),
        ]
    }
}
