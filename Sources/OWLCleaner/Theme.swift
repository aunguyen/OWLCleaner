import SwiftUI

/// Visual language for OWLCleaner — a calm, dark, "deep-clean" palette.
enum Theme {
    static let accent = Color(red: 0.18, green: 0.80, blue: 0.74)   // teal
    static let accentWarm = Color(red: 0.98, green: 0.72, blue: 0.22) // owl amber
    static let danger = Color(red: 0.94, green: 0.38, blue: 0.36)

    static let gaugeGradient = AngularGradient(
        colors: [accent, accentWarm, accent],
        center: .center
    )

    static let bg = Color(nsColor: .windowBackgroundColor)
}

/// Human-readable byte sizes (e.g. "1.8 GB").
enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: max(bytes, 0))
    }
}
