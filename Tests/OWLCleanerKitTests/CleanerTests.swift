import Foundation
import Testing
@testable import OWLCleanerKit

/// Records what was removed/trashed without touching the filesystem.
final class SpyRemover: FileRemoving, @unchecked Sendable {
    private(set) var removed: [URL] = []
    private(set) var trashed: [URL] = []
    var throwOn: URL?

    func removeItem(at url: URL) throws {
        if url == throwOn { throw CocoaError(.fileWriteNoPermission) }
        removed.append(url)
    }
    func trashItem(at url: URL) throws {
        if url == throwOn { throw CocoaError(.fileWriteNoPermission) }
        trashed.append(url)
    }
}

private func item(_ url: URL, bytes: Int64 = 100, mode: RemovalMode = .delete) -> CleanupItem {
    CleanupItem(url: url, sizeBytes: bytes, categoryID: "c", moduleID: "m", removalMode: mode)
}

@Suite("Cleaner")
struct CleanerTests {

    @Test("hard-deletes an allowed item and reports freed bytes")
    func deletesAllowed() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let file = box.makeFile("caches/a.cache", bytes: 100)
        let spy = SpyRemover()
        let cleaner = Cleaner(safetyGuard: SafetyGuard(safeRoots: [safe], denylist: []), remover: spy)

        let outcome = cleaner.clean([item(file, bytes: 100)], dryRun: false)

        #expect(spy.removed == [SafetyGuard.canonicalize(file)])
        #expect(outcome.removedCount == 1)
        #expect(outcome.freedBytes == 100)
        #expect(outcome.failures.isEmpty)
    }

    @Test("re-validates at delete time and refuses an item outside the safe root")
    func refusesOutside() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let outside = box.makeFile("outside/secret.txt", bytes: 100)
        let spy = SpyRemover()
        let cleaner = Cleaner(safetyGuard: SafetyGuard(safeRoots: [safe], denylist: []), remover: spy)

        let outcome = cleaner.clean([item(outside)], dryRun: false)

        #expect(spy.removed.isEmpty)
        #expect(outcome.removedCount == 0)
        #expect(outcome.failures.count == 1)
    }

    @Test("dry-run removes nothing but reports what would be freed")
    func dryRun() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let file = box.makeFile("caches/a.cache", bytes: 250)
        let spy = SpyRemover()
        let cleaner = Cleaner(safetyGuard: SafetyGuard(safeRoots: [safe], denylist: []), remover: spy)

        let outcome = cleaner.clean([item(file, bytes: 250)], dryRun: true)

        #expect(spy.removed.isEmpty)
        #expect(spy.trashed.isEmpty)
        #expect(outcome.freedBytes == 250)
        #expect(outcome.removedCount == 1)
    }

    @Test("trash-mode items are moved to Trash, not hard-deleted")
    func trashMode() {
        let box = TempSandbox()
        let safe = box.makeDir("files")
        let file = box.makeFile("files/big.zip", bytes: 999)
        let spy = SpyRemover()
        let cleaner = Cleaner(safetyGuard: SafetyGuard(safeRoots: [safe], denylist: []), remover: spy)

        let outcome = cleaner.clean([item(file, bytes: 999, mode: .trash)], dryRun: false)

        #expect(spy.removed.isEmpty)
        #expect(spy.trashed == [SafetyGuard.canonicalize(file)])
        #expect(outcome.freedBytes == 999)
    }

    @Test("a removal error is recorded as a failure, not counted as freed")
    func recordsFailure() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let file = box.makeFile("caches/a.cache", bytes: 100)
        let spy = SpyRemover()
        spy.throwOn = SafetyGuard.canonicalize(file)
        let cleaner = Cleaner(safetyGuard: SafetyGuard(safeRoots: [safe], denylist: []), remover: spy)

        let outcome = cleaner.clean([item(file, bytes: 100)], dryRun: false)

        #expect(outcome.removedCount == 0)
        #expect(outcome.freedBytes == 0)
        #expect(outcome.failures.count == 1)
    }
}
