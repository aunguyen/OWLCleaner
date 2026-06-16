import SwiftUI
import OWLCleanerKit

@main
struct OWLCleanerApp: App {
    @State private var model = AppModel()

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
