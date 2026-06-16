import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("SystemJunkModule")
struct SystemJunkModuleTests {

    @Test("standard roots include caches, logs and a user temp dir")
    func standardRoots() {
        let roots = SystemJunkModule.standardRoots()
        let paths = roots.map(\.url.path)
        #expect(paths.contains { $0.hasSuffix("/Library/Caches") })
        #expect(paths.contains { $0.hasSuffix("/Library/Logs") })
        #expect(roots.contains { $0.url.path.contains("/var/folders/") || $0.url.path.contains("/T") })
    }

    @Test("scanning the real machine completes; every item is deletable and offered with delete mode")
    func realScanIsSafe() async {
        let module = SystemJunkModule()
        let result = await module.scan { _ in }
        // Read-only contract: every offered item is a regular deletable thing.
        #expect(result.items.allSatisfy { $0.removalMode == .delete })
        #expect(result.items.allSatisfy { FileManager.default.isDeletableFile(atPath: $0.url.path) })
        #expect(result.moduleID == "system")
    }
}
