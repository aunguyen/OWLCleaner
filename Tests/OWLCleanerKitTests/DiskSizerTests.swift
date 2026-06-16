import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("DiskSizer")
struct DiskSizerTests {
    let sizer = DiskSizer()

    @Test("a file's allocated size is at least its logical size")
    func fileSize() {
        let box = TempSandbox()
        let file = box.makeFile("a.bin", bytes: 5000)
        let size = sizer.allocatedSize(of: file)
        #expect(size >= 5000)
    }

    @Test("a directory's size is the sum of its files' allocated sizes")
    func directorySize() {
        let box = TempSandbox()
        let dir = box.makeDir("d")
        let f1 = box.makeFile("d/one.bin", bytes: 1000)
        let f2 = box.makeFile("d/sub/two.bin", bytes: 2000)
        let expected = sizer.allocatedSize(of: f1) + sizer.allocatedSize(of: f2)
        #expect(sizer.allocatedSize(of: dir) == expected)
    }

    @Test("a symlink contributes nothing and is not followed")
    func symlinkNotFollowed() {
        let box = TempSandbox()
        let dir = box.makeDir("d")
        let real = box.makeFile("d/real.bin", bytes: 4096)
        let huge = box.makeFile("outside/huge.bin", bytes: 1_000_000)
        box.makeSymlink("d/link", to: huge)
        // Only the real file counts; the symlink (and its big target) are ignored.
        #expect(sizer.allocatedSize(of: dir) == sizer.allocatedSize(of: real))
    }

    @Test("a bare symlink reports zero")
    func bareSymlinkZero() {
        let box = TempSandbox()
        let target = box.makeFile("outside/t.bin", bytes: 50_000)
        let link = box.makeSymlink("link", to: target)
        #expect(sizer.allocatedSize(of: link) == 0)
    }
}
