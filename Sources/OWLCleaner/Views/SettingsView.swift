import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Cleaning") {
                Toggle("Dry run — simulate cleaning without deleting", isOn: $model.dryRun)
                Text("When on, OWLCleaner reports what it *would* remove but changes nothing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Large & Old Files") {
                Picker("Only show files larger than", selection: $model.largeOldMinBytes) {
                    Text("50 MB").tag(Int64(50 * 1024 * 1024))
                    Text("100 MB").tag(Int64(100 * 1024 * 1024))
                    Text("250 MB").tag(Int64(250 * 1024 * 1024))
                    Text("500 MB").tag(Int64(500 * 1024 * 1024))
                    Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                }
            }
            Section("Permissions") {
                Button("Open Full Disk Access settings…") { openFullDiskAccess() }
                Text("Grant OWLCleaner Full Disk Access so it can reach system and app caches.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 280)
    }

    private func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
