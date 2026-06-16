import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("DirectoryJunkScanner")
struct DirectoryJunkScannerTests {

    @Test("lists top-level children as items, excluding the root and empty entries")
    func listsChildren() async {
        let box = TempSandbox()
        let caches = box.makeDir("Caches")
        box.makeFile("Caches/AppA/data.bin", bytes: 5000)
        box.makeFile("Caches/AppB/log.txt", bytes: 3000)
        box.makeDir("Caches/Empty") // zero bytes -> filtered out

        let scanner = DirectoryJunkScanner(
            moduleID: "system",
            roots: [.init(url: caches, categoryID: "caches")],
            removalMode: .delete,
            defaultSelected: true
        )
        let result = await scanner.scan { _ in }

        #expect(Set(result.items.map(\.displayName)) == ["AppA", "AppB"])
        #expect(result.items.allSatisfy { $0.sizeBytes > 0 })
        #expect(result.items.allSatisfy { $0.moduleID == "system" && $0.categoryID == "caches" })
        #expect(result.items.allSatisfy { $0.removalMode == .delete && $0.defaultSelected })
    }

    @Test("sizes each item with the disk sizer")
    func sizesItems() async {
        let box = TempSandbox()
        let caches = box.makeDir("Caches")
        let appDir = box.makeDir("Caches/App")
        box.makeFile("Caches/App/a.bin", bytes: 4096)
        box.makeFile("Caches/App/b.bin", bytes: 8192)
        let expected = DiskSizer().allocatedSize(of: appDir)

        let scanner = DirectoryJunkScanner(
            moduleID: "system",
            roots: [.init(url: caches, categoryID: "caches")],
            removalMode: .delete,
            defaultSelected: true
        )
        let result = await scanner.scan { _ in }
        #expect(result.items.first?.sizeBytes == expected)
        #expect(result.totalBytes == expected)
    }

    @Test("tags items from different roots with their own categories")
    func multipleRoots() async {
        let box = TempSandbox()
        let caches = box.makeDir("Caches")
        let logs = box.makeDir("Logs")
        box.makeFile("Caches/App/c.bin", bytes: 2000)
        box.makeFile("Logs/system.log", bytes: 2000)

        let scanner = DirectoryJunkScanner(
            moduleID: "system",
            roots: [.init(url: caches, categoryID: "caches"), .init(url: logs, categoryID: "logs")],
            removalMode: .delete,
            defaultSelected: true
        )
        let result = await scanner.scan { _ in }
        let byCategory = Dictionary(grouping: result.items, by: \.categoryID)
        #expect(byCategory["caches"]?.count == 1)
        #expect(byCategory["logs"]?.count == 1)
    }

    @Test("an item we cannot delete is surfaced as needing elevated access, not offered")
    func nonDeletableSkipped() async {
        let box = TempSandbox()
        let caches = box.makeDir("Caches")
        box.makeFile("Caches/rootowned.bin", bytes: 5000)
        // Make the root read-only so its child cannot be deleted (mimics /Library/Caches).
        let fm = FileManager.default
        try? fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: caches.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: caches.path) }

        let scanner = DirectoryJunkScanner(
            moduleID: "system",
            roots: [.init(url: caches, categoryID: "system")],
            removalMode: .delete,
            defaultSelected: true
        )
        let result = await scanner.scan { _ in }

        #expect(result.items.isEmpty)
        #expect(result.skipped.contains { $0.reason == .needsElevatedAccess })
    }

    @Test("a missing root yields no items and does not crash")
    func missingRoot() async {
        let box = TempSandbox()
        let missing = box.url("DoesNotExist")
        let scanner = DirectoryJunkScanner(
            moduleID: "system",
            roots: [.init(url: missing, categoryID: "caches")],
            removalMode: .delete,
            defaultSelected: true
        )
        let result = await scanner.scan { _ in }
        #expect(result.items.isEmpty)
    }
}
