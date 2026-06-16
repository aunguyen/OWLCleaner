import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("SafetyGuard — containment")
struct SafetyGuardContainmentTests {

    @Test("allows a file directly inside a safe root")
    func allowsDirectChild() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let file = box.makeFile("caches/app.cache", bytes: 10)
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(file).isAllowed)
    }

    @Test("allows a deeply nested file inside a safe root")
    func allowsNestedChild() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let file = box.makeFile("caches/a/b/c/deep.cache", bytes: 5)
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(file).isAllowed)
    }

    @Test("rejects the safe root itself — only contents are deletable")
    func rejectsSafeRootItself() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(safe) == .rejected(.isSafeRootItself))
    }

    @Test("rejects a path outside every safe root")
    func rejectsOutside() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let outside = box.makeFile("elsewhere/secret.txt", bytes: 1)
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(outside) == .rejected(.outsideSafeRoot))
    }

    @Test("rejects a `..` traversal that escapes the safe root")
    func rejectsLexicalTraversal() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        box.makeFile("elsewhere/secret.txt", bytes: 1)
        // caches/sub/../../elsewhere/secret.txt  ->  elsewhere/secret.txt (outside)
        let traversal = safe.appendingPathComponent("sub/../../elsewhere/secret.txt")
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(traversal) == .rejected(.outsideSafeRoot))
    }
}

@Suite("SafetyGuard — symlinks & denylist (adversarial)")
struct SafetyGuardAdversarialTests {

    @Test("rejects a candidate whose parent dir is a symlink escaping the safe root")
    func rejectsSymlinkedParentEscape() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let outside = box.makeDir("outside")
        // caches/evil -> outside ; deleting caches/evil/file would hit outside/file
        box.makeSymlink("caches/evil", to: outside)
        let candidate = safe.appendingPathComponent("evil/file.txt")
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(candidate) == .rejected(.outsideSafeRoot))
    }

    @Test("rejects a denylisted descendant even when inside a (misconfigured) broad safe root")
    func denylistTakesPrecedence() {
        let box = TempSandbox()
        let broad = box.root                    // misconfigured: everything is "inside"
        let precious = box.makeDir("Documents") // must never be touched
        let file = box.makeFile("Documents/important.txt", bytes: 100)
        let guard0 = SafetyGuard(safeRoots: [broad], denylist: [precious])
        #expect(guard0.validate(file) == .rejected(.denylisted))
    }

    @Test("allows a leaf symlink inside a safe root — removeItem deletes the link, not its target")
    func allowsLeafSymlink() {
        let box = TempSandbox()
        let safe = box.makeDir("caches")
        let outsideFile = box.makeFile("outside/real.txt", bytes: 50)
        let link = box.makeSymlink("caches/link", to: outsideFile)
        let guard0 = SafetyGuard(safeRoots: [safe], denylist: [])
        #expect(guard0.validate(link).isAllowed)
    }

    @Test("allows a candidate inside a safe root that is itself reached via a symlink")
    func allowsSymlinkedSafeRoot() {
        let box = TempSandbox()
        let real = box.makeDir("realcaches")
        let file = box.makeFile("realcaches/app.cache", bytes: 10)
        let linkedRoot = box.makeSymlink("caches", to: real) // safe root passed as a symlink
        let guard0 = SafetyGuard(safeRoots: [linkedRoot], denylist: [])
        let viaLink = linkedRoot.appendingPathComponent("app.cache")
        #expect(guard0.validate(viaLink).isAllowed)
        _ = file
    }
}
