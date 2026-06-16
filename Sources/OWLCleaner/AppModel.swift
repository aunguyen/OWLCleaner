import Foundation
import Observation
import OWLCleanerKit

/// The single source of truth for the UI. Owns the modules, runs scans
/// concurrently off the main actor, tracks selection, and performs cleaning
/// through a SafetyGuard built from the union of every module's safe roots.
@MainActor
@Observable
final class AppModel {

    enum Phase: Equatable {
        case idle
        case scanning
        case results
        case cleaning
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    private(set) var results: [ModuleScanResult] = []
    private(set) var lastOutcome: CleanOutcome?
    var selection: Set<String> = []
    var dryRun = false
    var selectedSidebar: SidebarItem = .smart

    /// Large & Old finder settings; the module is rebuilt from these.
    var largeOldFolder: URL?
    var largeOldMinBytes: Int64 = 100 * 1024 * 1024

    private let baseModules: [any CleanupModule]

    init(baseModules: [any CleanupModule] = [SystemJunkModule(), TrashModule(), DeveloperModule()]) {
        self.baseModules = baseModules
    }

    var modules: [any CleanupModule] {
        baseModules + [LargeOldFilesModule(searchRoot: largeOldFolder, minBytes: largeOldMinBytes)]
    }

    // MARK: - Derived state

    func module(id: String) -> (any CleanupModule)? { modules.first { $0.id == id } }

    func result(forModule id: String) -> ModuleScanResult? { results.first { $0.moduleID == id } }

    var allItems: [CleanupItem] { results.flatMap(\.items) }

    func items(forModule id: String) -> [CleanupItem] { result(forModule: id)?.items ?? [] }

    var selectedItems: [CleanupItem] { allItems.filter { selection.contains($0.id) } }

    var totalFoundBytes: Int64 { allItems.reduce(0) { $0 + $1.sizeBytes } }

    var totalSelectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.sizeBytes } }

    func bytes(forModule id: String) -> Int64 {
        items(forModule: id).reduce(0) { $0 + $1.sizeBytes }
    }

    var hasResults: Bool { !allItems.isEmpty }

    // MARK: - Selection helpers

    func isSelected(_ item: CleanupItem) -> Bool { selection.contains(item.id) }

    func toggle(_ item: CleanupItem) {
        if selection.contains(item.id) { selection.remove(item.id) }
        else { selection.insert(item.id) }
    }

    func setSelected(_ items: [CleanupItem], _ on: Bool) {
        for item in items {
            if on { selection.insert(item.id) } else { selection.remove(item.id) }
        }
    }

    // MARK: - Actions

    func scan() async {
        phase = .scanning
        progress = 0
        results = []
        selection = []
        lastOutcome = nil

        let mods = modules
        let count = max(mods.count, 1)
        var collected: [ModuleScanResult] = []

        await withTaskGroup(of: ModuleScanResult.self) { group in
            for module in mods {
                group.addTask { await module.scan { _ in } }
            }
            var done = 0
            for await result in group {
                done += 1
                collected.append(result)
                results = collected   // stream in so the gauge total grows live
                progress = Double(done) / Double(count)
            }
        }

        // Preserve module declaration order for stable display.
        let order = Dictionary(uniqueKeysWithValues: mods.enumerated().map { ($1.id, $0) })
        results = collected.sorted { (order[$0.moduleID] ?? 0) < (order[$1.moduleID] ?? 0) }
        selection = Set(allItems.filter(\.defaultSelected).map(\.id))
        phase = .results
    }

    /// Re-scan a single module (used after the user picks a Large & Old folder).
    func scanModule(_ id: String) async {
        guard let module = module(id: id) else { return }
        let result = await module.scan { _ in }
        var updated = results.filter { $0.moduleID != id }
        updated.append(result)
        let order = Dictionary(uniqueKeysWithValues: modules.enumerated().map { ($1.id, $0) })
        results = updated.sorted { (order[$0.moduleID] ?? 0) < (order[$1.moduleID] ?? 0) }
        for item in result.items where item.defaultSelected { selection.insert(item.id) }
        if phase == .idle || phase == .finished { phase = .results }
    }

    /// Set the Large & Old search folder and scan it.
    func chooseLargeOldFolder(_ url: URL) async {
        largeOldFolder = url
        await scanModule("largeold")
    }

    func clean(filterModuleID: String? = nil) async {
        let selected = selectedItems.filter { filterModuleID == nil || $0.moduleID == filterModuleID }
        guard !selected.isEmpty else { return }
        phase = .cleaning

        let dry = dryRun
        let mods = modules

        // Clean each module's items with that module's own guard: cache modules
        // keep the default denylist; Large & Old trashes user files in its folder.
        let outcome = await Task.detached { () -> CleanOutcome in
            var accumulated = CleanOutcome()
            for module in mods {
                let group = selected.filter { $0.moduleID == module.id }
                guard !group.isEmpty else { continue }
                let result = Cleaner(safetyGuard: module.cleaningGuard()).clean(group, dryRun: dry)
                accumulated.removed += result.removed
                accumulated.freedBytes += result.freedBytes
                accumulated.failures += result.failures
            }
            return accumulated
        }.value

        lastOutcome = outcome
        if !dry {
            // Drop cleaned items from the displayed results and selection.
            let removed = Set(outcome.removed.map(\.path))
            results = results.map { result in
                ModuleScanResult(
                    moduleID: result.moduleID,
                    items: result.items.filter { !removed.contains($0.url.path) },
                    skipped: result.skipped
                )
            }
            selection = selection.filter { !removed.contains($0) }  // item ids are paths
        }
        phase = .finished
    }

    func reset() {
        phase = .idle
        progress = 0
        results = []
        selection = []
        lastOutcome = nil
    }
}

/// Sidebar destinations: an aggregate "Smart" view plus one per module id.
enum SidebarItem: Hashable {
    case smart
    case module(String)
}
