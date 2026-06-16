import Foundation

/// Distinguishes "safe to auto-remove" junk from "regenerable but costly" items.
///
/// Living inside `~/Library/Caches` does not by itself make something disposable.
/// Several tools store *installed payloads* (browser binaries, test runners) there,
/// and Xcode keeps slow-to-rebuild device symbols. These are still safe to delete —
/// nothing irreplaceable is lost — but they should be **opt-in** (deselected, with a
/// note) rather than auto-cleaned, because re-acquiring them costs time/bandwidth.
public enum CautionRules {

    /// Cache directory names that actually hold installed binaries/payloads.
    private static let installedPayloadCaches: Set<String> = [
        "ms-playwright",            // Playwright browser binaries
        "ms-playwright-go", "ms-playwright-java", "ms-playwright-python", "ms-playwright-dotnet",
        "Cypress",                  // Cypress test-runner binary
        "puppeteer",                // Puppeteer-managed Chromium
        "electron", "electron-builder", // downloaded Electron runtimes
        "deno",                     // Deno dependency cache / compiled binaries
    ]

    /// A caution note if this item is regenerable-but-costly (and should be
    /// offered as opt-in), or nil if it is ordinary disposable junk.
    public static func note(forItemAt url: URL, categoryID: String) -> String? {
        let name = url.lastPathComponent

        if installedPayloadCaches.contains(name) {
            return "Re-downloads binaries on next use"
        }
        if categoryID == DeveloperModule.deviceSupport.id {
            return "Xcode re-extracts symbols on next device connect"
        }
        return nil
    }
}
