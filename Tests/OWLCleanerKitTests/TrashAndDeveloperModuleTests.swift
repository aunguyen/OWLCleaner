import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("TrashModule")
struct TrashModuleTests {

    @Test("standard roots include the user's ~/.Trash")
    func standardRootsIncludeHomeTrash() {
        let roots = TrashModule.standardRoots()
        #expect(roots.contains { $0.url.lastPathComponent == ".Trash" })
        #expect(roots.allSatisfy { $0.categoryID == TrashModule.bins.id })
    }

    @Test("scans trash entries as delete-mode items")
    func scansEntries() async {
        let box = TempSandbox()
        let trash = box.makeDir("Trash")
        box.makeFile("Trash/old-download.zip", bytes: 4096)
        box.makeFile("Trash/note.txt", bytes: 1000)

        let module = TrashModule(roots: [.init(url: trash, categoryID: TrashModule.bins.id)])
        let result = await module.scan { _ in }

        #expect(result.items.count == 2)
        #expect(result.items.allSatisfy { $0.removalMode == .delete })
        #expect(result.moduleID == "trash")
    }
}

@Suite("DeveloperModule")
struct DeveloperModuleTests {

    @Test("standard roots include DerivedData and package caches")
    func standardRoots() {
        let paths = DeveloperModule.standardRoots().map(\.url.path)
        #expect(paths.contains { $0.hasSuffix("Xcode/DerivedData") })
        #expect(paths.contains { $0.hasSuffix(".npm/_cacache") })
        #expect(paths.contains { $0.hasSuffix("Caches/Homebrew") })
    }

    @Test("tags items by their developer category and uses delete mode")
    func categoryTagging() async {
        let box = TempSandbox()
        let derived = box.makeDir("DerivedData")
        let npm = box.makeDir("npm")
        box.makeFile("DerivedData/MyApp-abc/build.o", bytes: 9000)
        box.makeFile("npm/cache.bin", bytes: 3000)

        let module = DeveloperModule(roots: [
            .init(url: derived, categoryID: DeveloperModule.derivedData.id),
            .init(url: npm, categoryID: DeveloperModule.packages.id),
        ])
        let result = await module.scan { _ in }
        let cats = Dictionary(grouping: result.items, by: \.categoryID)
        #expect(cats[DeveloperModule.derivedData.id]?.count == 1)
        #expect(cats[DeveloperModule.packages.id]?.count == 1)
        #expect(result.items.allSatisfy { $0.removalMode == .delete })
    }
}
