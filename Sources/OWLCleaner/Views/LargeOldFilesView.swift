import SwiftUI
import AppKit
import OWLCleanerKit

/// Dedicated view for the Large & Old finder: pick a folder, review big files,
/// move selections to the Trash (recoverable).
struct LargeOldFilesView: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    private let moduleID = "largeold"
    private var result: ModuleScanResult? { model.result(forModule: moduleID) }
    private var items: [CleanupItem] { result?.items ?? [] }
    private var selectedHere: [CleanupItem] { items.filter(model.isSelected) }
    private var selectedBytes: Int64 { selectedHere.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.top, 16)
            content
        }
        .confirmationDialog(
            "Move \(selectedHere.count) files to the Trash?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Move \(ByteFormat.string(selectedBytes)) to Trash") {
                Task { await model.clean(filterModuleID: moduleID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These are your own files. They are moved to the Trash and can be recovered.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Large & Old Files")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                if let folder = model.largeOldFolder {
                    Text(folder.path).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                } else {
                    Text("Pick a folder to scan for files over \(ByteFormat.string(model.largeOldMinBytes)).")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button { chooseFolder() } label: {
                    Label(model.largeOldFolder == nil ? "Choose Folder…" : "Change Folder…",
                          systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !items.isEmpty {
                    Button {
                        if model.dryRun { Task { await model.clean(filterModuleID: moduleID) } }
                        else { confirming = true }
                    } label: {
                        Text(model.dryRun ? "Trash (Dry Run)" : "Move to Trash")
                            .fontWeight(.semibold).frame(minWidth: 130, minHeight: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.dryRun ? Theme.accentWarm : Theme.accent)
                    .controlSize(.large)
                    .disabled(selectedBytes == 0 || model.phase == .cleaning)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }

    @ViewBuilder
    private var content: some View {
        if model.largeOldFolder == nil {
            prompt(icon: "doc.text.magnifyingglass", title: "Find space hogs",
                   message: "Choose a folder like Downloads or Movies to surface large files you can review.")
        } else if items.isEmpty {
            prompt(icon: "checkmark.seal.fill", title: "Nothing large found",
                   message: "No files over \(ByteFormat.string(model.largeOldMinBytes)) in this folder.")
        } else {
            List {
                Section {
                    ForEach(items) { item in
                        Toggle(isOn: Binding(get: { model.isSelected(item) }, set: { _ in model.toggle(item) })) {
                            HStack {
                                Text(item.displayName).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text(ByteFormat.string(item.sizeBytes))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                } header: {
                    Text("\(items.count) files · \(ByteFormat.string(items.reduce(0) { $0 + $1.sizeBytes }))")
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private func prompt(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text(title).font(.title.weight(.semibold))
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder to scan for large files"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.chooseLargeOldFolder(url) }
        }
    }
}
