import Foundation
import Testing
@testable import OWLCleanerKit

@Suite("CautionRules — regenerable-but-costly detection")
struct CautionRulesTests {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/Users/x/Library/Caches/\(name)")
    }

    @Test("flags installed-payload caches that masquerade as throwaway caches")
    func flagsInstalledPayloads() {
        #expect(CautionRules.note(forItemAt: url("ms-playwright"), categoryID: "system.caches") != nil)
        #expect(CautionRules.note(forItemAt: url("Cypress"), categoryID: "system.caches") != nil)
        #expect(CautionRules.note(forItemAt: url("puppeteer"), categoryID: "system.caches") != nil)
        #expect(CautionRules.note(forItemAt: url("electron"), categoryID: "system.caches") != nil)
    }

    @Test("does not flag ordinary disposable caches")
    func leavesOrdinaryCachesAlone() {
        #expect(CautionRules.note(forItemAt: url("org.swift.swiftpm"), categoryID: "system.caches") == nil)
        #expect(CautionRules.note(forItemAt: url("BraveSoftware"), categoryID: "system.caches") == nil)
        #expect(CautionRules.note(forItemAt: url("Homebrew"), categoryID: "system.caches") == nil)
    }

    @Test("flags Xcode device support (slow to re-extract)")
    func flagsDeviceSupport() {
        let ds = URL(fileURLWithPath: "/Users/x/Library/Developer/Xcode/iOS DeviceSupport/iPhone18,2 26.5.1")
        #expect(CautionRules.note(forItemAt: ds, categoryID: DeveloperModule.deviceSupport.id) != nil)
    }
}
