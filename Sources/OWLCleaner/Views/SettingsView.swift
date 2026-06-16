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
