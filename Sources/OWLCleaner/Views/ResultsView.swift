import SwiftUI
import OWLCleanerKit

struct ResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    private var visibleResults: [ModuleScanResult] {
        switch model.selectedSidebar {
        case .smart: return model.results
        case .module(let id): return model.results.filter { $0.moduleID == id }
        }
    }

    private var title: String {
        switch model.selectedSidebar {
        case .smart: return "Smart Scan"
        case .module(let id): return model.module(id: id)?.title ?? "Cleanup"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if model.phase == .finished, let outcome = model.lastOutcome {
                CompletionBanner(outcome: outcome, dryRun: model.dryRun)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
            }
            Divider().padding(.top, 16)
            content
        }
        .confirmationDialog(
            "Clean \(model.selectedItems.count) items?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Clean \(ByteFormat.string(model.totalSelectedBytes))", role: .destructive) {
                Task { await model.clean() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the selected caches, logs and temporary files. Large & old files are moved to the Trash instead.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            cleanButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }

    private var subtitle: String {
        let selected = model.selectedItems.count
        let total = model.allItems.count
        return "\(ByteFormat.string(model.totalSelectedBytes)) selected · \(selected) of \(total) items"
    }

    private var cleanButton: some View {
        Button {
            if model.dryRun { Task { await model.clean() } } else { confirming = true }
        } label: {
            HStack(spacing: 8) {
                if model.phase == .cleaning {
                    ProgressView().controlSize(.small)
                }
                Text(model.dryRun ? "Clean (Dry Run)" : "Clean")
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 130, minHeight: 26)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.dryRun ? Theme.accentWarm : Theme.accent)
        .controlSize(.large)
        .disabled(model.totalSelectedBytes == 0 || model.phase == .cleaning)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.allItems.isEmpty {
            allClean
        } else {
            List {
                ForEach(visibleResults, id: \.moduleID) { result in
                    ModuleSection(result: result)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private var allClean: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.accent)
            Text("You're all clean")
                .font(.title.weight(.semibold))
            Text("No junk found in the scanned locations.")
                .foregroundStyle(.secondary)
            Button("Scan again") { Task { await model.scan() } }
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Module section

private struct ModuleSection: View {
    @Environment(AppModel.self) private var model
    let result: ModuleScanResult

    private var module: (any CleanupModule)? { model.module(id: result.moduleID) }

    private var groups: [(category: CleanupCategory, items: [CleanupItem])] {
        guard let module else { return [] }
        let byCat = Dictionary(grouping: result.items, by: \.categoryID)
        return module.categories.compactMap { cat in
            guard let items = byCat[cat.id], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.sizeBytes > $1.sizeBytes })
        }
    }

    var body: some View {
        Section {
            ForEach(groups, id: \.category.id) { group in
                CategoryRows(category: group.category, items: group.items)
            }
            if result.skipped.contains(where: { $0.reason == .needsElevatedAccess }) {
                Label("Some system items need elevated access and were skipped.",
                      systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Label(module?.title ?? result.moduleID, systemImage: module?.systemImage ?? "folder")
                    .font(.headline)
                Spacer()
                Text(ByteFormat.string(result.totalBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CategoryRows: View {
    @Environment(AppModel.self) private var model
    let category: CleanupCategory
    let items: [CleanupItem]

    private var allSelected: Bool { items.allSatisfy(model.isSelected) }

    var body: some View {
        Toggle(isOn: Binding(
            get: { allSelected },
            set: { model.setSelected(items, $0) }
        )) {
            HStack {
                Image(systemName: category.systemImage).foregroundStyle(Theme.accent).frame(width: 18)
                Text(category.title).fontWeight(.medium)
                Spacer()
                Text(ByteFormat.string(items.reduce(0) { $0 + $1.sizeBytes }))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)

        ForEach(items) { item in
            ItemRow(item: item)
                .padding(.leading, 26)
        }
    }
}

private struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: CleanupItem

    var body: some View {
        Toggle(isOn: Binding(
            get: { model.isSelected(item) },
            set: { _ in model.toggle(item) }
        )) {
            HStack {
                Text(item.displayName).lineLimit(1).truncationMode(.middle)
                if let note = item.note {
                    Text(note).font(.caption2).foregroundStyle(Theme.accentWarm)
                }
                Spacer()
                Text(ByteFormat.string(item.sizeBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

// MARK: - Completion banner

private struct CompletionBanner: View {
    @Environment(AppModel.self) private var model
    let outcome: CleanOutcome
    let dryRun: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: dryRun ? "eye" : "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(dryRun ? Theme.accentWarm : Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(dryRun
                     ? "Dry run: would free \(ByteFormat.string(outcome.freedBytes))"
                     : "Freed \(ByteFormat.string(outcome.freedBytes))")
                    .font(.headline)
                Text("\(outcome.removedCount) items" +
                     (outcome.failures.isEmpty ? "" : " · \(outcome.failures.count) could not be removed"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Scan again") { Task { await model.scan() } }
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
