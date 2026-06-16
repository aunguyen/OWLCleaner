import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("End-to-end pipeline")
struct EndToEndTests {

    @Test("scan → dry-run (deletes nothing) → real clean (removes everything, reports freed)")
    func scanThenClean() async {
        let box = TempSandbox()
        let caches = box.makeDir("Caches")
        box.makeFile("Caches/AppA/big.bin", bytes: 8192)
        box.makeFile("Caches/AppB/log.bin", bytes: 4096)

        let module = SystemJunkModule(roots: [.init(url: caches, categoryID: SystemJunkModule.userCaches.id)])
        let result = await module.scan { _ in }
        #expect(result.items.count == 2)

        let fm = FileManager.default
        let cleaner = Cleaner(safetyGuard: module.cleaningGuard())

        // Dry run changes nothing.
        let dry = cleaner.clean(result.items, dryRun: true)
        #expect(dry.freedBytes == result.totalBytes)
        #expect(fm.fileExists(atPath: box.url("Caches/AppA").path))

        // Real clean removes the items and reports the freed total.
        let real = cleaner.clean(result.items, dryRun: false)
        #expect(real.freedBytes == result.totalBytes)
        #expect(real.failures.isEmpty)
        #expect(!fm.fileExists(atPath: box.url("Caches/AppA").path))
        #expect(!fm.fileExists(atPath: box.url("Caches/AppB").path))
        // The safe root itself survives — only its contents were removed.
        #expect(fm.fileExists(atPath: caches.path))
    }
}
