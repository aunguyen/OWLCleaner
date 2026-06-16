import SwiftUI
import Foundation
import Dispatch
import OWLCleanerKit

@main
struct OWLCleanerApp: App {
    @State private var model = AppModel()

    init() {
        // Headless self-test: drive the real AppModel pipeline (scan → dry-run
        // clean) without showing the UI. Verifies model integration + that real
        // locations resolve. DRY-RUN ONLY — never deletes the user's files.
        if ProcessInfo.processInfo.environment["OWL_SELFTEST"] != nil {
            runSelfTestAndExit()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 880, minHeight: 580)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OWLCleaner") {}
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

/// Drives the real AppModel pipeline once and exits. Blocks the main thread on
/// the run loop so the @MainActor async work is serviced; the scene never shows.
private func runSelfTestAndExit() -> Never {
    print("OWLCleaner self-test — scanning real user-reachable locations (dry-run only)…")

    // Watchdog so the process never hangs.
    Task.detached {
        try? await Task.sleep(for: .seconds(60))
        print("SELFTEST TIMEOUT"); exit(2)
    }

    let verbose = ProcessInfo.processInfo.environment["OWL_SELFTEST"] == "list"

    Task { @MainActor in
        let model = AppModel()
        await model.scan()
        print("  scan: \(ByteFormat.string(model.totalFoundBytes)) across \(model.allItems.count) items, \(model.modules.count) modules")

        if verbose {
            for result in model.results {
                let module = model.module(id: result.moduleID)
                print("\n### \(module?.title ?? result.moduleID) — \(ByteFormat.string(result.totalBytes)), \(result.items.count) items, \(result.skipped.count) skipped")
                for item in result.items.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(20) {
                    let tag = item.defaultSelected ? "[auto]   " : "[opt-in] "
                    let note = item.note.map { "  — \($0)" } ?? ""
                    print(String(format: "  %@%10@  %@%@", tag, ByteFormat.string(item.sizeBytes) as NSString, item.url.lastPathComponent, note))
                }
            }
            exit(0)
        }

        model.dryRun = true
        await model.clean()
        if let outcome = model.lastOutcome {
            print("  dry-run clean: would free \(ByteFormat.string(outcome.freedBytes)) across \(outcome.removedCount) items (\(outcome.failures.count) blocked)")
        }

        let ok = model.allItems.count > 0 && model.totalFoundBytes > 0
        print(ok ? "SELFTEST OK — AppModel pipeline runs end to end" : "SELFTEST EMPTY — scan produced no items (suspicious)")
        exit(ok ? 0 : 1)
    }

    // Service the main queue (where the @MainActor task runs) until it exit()s.
    dispatchMain()
}
