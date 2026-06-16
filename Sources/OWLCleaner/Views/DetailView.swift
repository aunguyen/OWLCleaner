import SwiftUI
import OWLCleanerKit

struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.25), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if case .module("largeold") = model.selectedSidebar {
                LargeOldFilesView()
            } else {
                switch model.phase {
                case .idle:
                    IdleHero()
                case .scanning:
                    ScanningView()
                case .results, .cleaning, .finished:
                    ResultsView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct IdleHero: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Theme.gaugeGradient.opacity(0.18)).frame(width: 180, height: 180)
                Text("🦉").font(.system(size: 96))
            }
            VStack(spacing: 8) {
                Text("Ready to tidy up")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Scan your Mac for caches, logs, temporary files and other junk.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            Button {
                Task { await model.scan() }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .frame(width: 180, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
            Spacer()
        }
        .padding(40)
    }
}

private struct ScanningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ScanGauge(
                progress: model.progress,
                bytesLabel: ByteFormat.string(model.totalFoundBytes),
                caption: "Scanning…",
                spinning: true
            )
            Text("\(Int(model.progress * 100))% complete")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(40)
    }
}
