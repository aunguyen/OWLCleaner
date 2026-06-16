import SwiftUI

/// Animated circular gauge shown while scanning and at rest. The ring sweeps with
/// progress; the center reads the total size discovered so far.
struct ScanGauge: View {
    var progress: Double          // 0...1
    var bytesLabel: String
    var caption: String
    var spinning: Bool

    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 14)

            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(Theme.gaugeGradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .rotationEffect(.degrees(spinning ? rotation : 0))
                .animation(.easeInOut(duration: 0.4), value: progress)

            VStack(spacing: 6) {
                Text(bytesLabel)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 240, height: 240)
        .onAppear {
            if spinning {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}
