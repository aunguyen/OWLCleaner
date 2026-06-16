import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("LargeOldFilesModule")
struct LargeOldFilesModuleTests {

    @Test("with no folder chosen, scanning finds nothing")
    func noFolder() async {
        let module = LargeOldFilesModule(searchRoot: nil)
        let result = await module.scan { _ in }
        #expect(result.items.isEmpty)
    }

    @Test("finds files at or above the size threshold, recursively, ignoring small ones")
    func findsLargeFiles() async {
        let box = TempSandbox()
        let folder = box.makeDir("Downloads")
        box.makeFile("Downloads/big.zip", bytes: 20_000)
        box.makeFile("Downloads/sub/huge.iso", bytes: 50_000)
        box.makeFile("Downloads/tiny.txt", bytes: 100)

        let module = LargeOldFilesModule(searchRoot: folder, minBytes: 10_000)
        let result = await module.scan { _ in }

        #expect(Set(result.items.map(\.displayName)) == ["big.zip", "huge.iso"])
        #expect(result.items.allSatisfy { $0.removalMode == .trash })
        #expect(result.items.allSatisfy { !$0.defaultSelected })   // opt-in only
        #expect(result.items.first?.sizeBytes ?? 0 >= result.items.last?.sizeBytes ?? 0) // largest first
    }

    @Test("does not follow symlinks out of the chosen folder")
    func ignoresSymlinks() async {
        let box = TempSandbox()
        let folder = box.makeDir("Downloads")
        box.makeFile("outside/secret-huge.bin", bytes: 80_000)
        box.makeSymlink("Downloads/link-to-outside", to: box.url("outside"))

        let module = LargeOldFilesModule(searchRoot: folder, minBytes: 10_000)
        let result = await module.scan { _ in }
        #expect(result.items.isEmpty)
    }

    @Test("cleaning guard is trash-scoped to the folder with no cache denylist")
    func cleaningGuardScoped() {
        let box = TempSandbox()
        let folder = box.makeDir("Downloads")
        let file = box.makeFile("Downloads/big.zip", bytes: 20_000)
        let module = LargeOldFilesModule(searchRoot: folder, minBytes: 10_000)
        #expect(module.cleaningGuard().validate(file).isAllowed)
    }
}
