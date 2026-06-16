import SwiftUI
import OWLCleanerKit

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 224, ideal: 248, max: 300)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 560, ideal: 720)
        }
        .navigationTitle("")
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            brand
            List(selection: $model.selectedSidebar) {
                Section {
                    SidebarRow(item: .smart, title: "Smart Scan",
                               systemImage: "sparkles", bytes: model.totalFoundBytes, isHero: true)
                    .tag(SidebarItem.smart)
                }
                Section("Cleanup") {
                    ForEach(model.modules, id: \.id) { module in
                        SidebarRow(item: .module(module.id), title: module.title,
                                   systemImage: module.systemImage, bytes: model.bytes(forModule: module.id))
                        .tag(SidebarItem.module(module.id))
                    }
                }
            }
            .listStyle(.sidebar)
            Spacer(minLength: 0)
            footer
        }
        .background(.ultraThinMaterial)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.gaugeGradient).frame(width: 34, height: 34)
                Text("🦉").font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("OWLCleaner").font(.headline)
                Text("Keep your Mac tidy").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack {
            Image(systemName: "lock.shield")
                .foregroundStyle(Theme.accent)
            Text("Full Disk Access recommended")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let title: String
    let systemImage: String
    let bytes: Int64
    var isHero: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(isHero ? AnyShapeStyle(Theme.gaugeGradient) : AnyShapeStyle(Theme.accent))
                .frame(width: 20)
            Text(title).fontWeight(isHero ? .semibold : .regular)
            Spacer()
            if bytes > 0 {
                Text(ByteFormat.string(bytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
