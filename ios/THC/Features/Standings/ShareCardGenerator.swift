import UIKit
import SwiftUI
import Shared

/// Generates a shareable scorecard image using SwiftUI's `ImageRenderer`.
enum ShareCardGenerator {
    /// Generate a scorecard UIImage for a completed round.
    ///
    /// - Parameters:
    ///   - player: The player whose round is being shared.
    ///   - round: The completed round.
    ///   - holeScores: Optional per-hole breakdown.
    /// - Returns: A `UIImage` suitable for sharing via `UIActivityViewController`.
    @MainActor
    static func generateImage(
        player: Player,
        round: Round,
        holeScores: [HoleScore]? = nil
    ) -> UIImage {
        let view = ShareCardContent(player: player, round: round, holeScores: holeScores)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0  // Retina quality
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - ShareCardContent

/// The SwiftUI view rendered into an image.
struct ShareCardContent: View {
    let player: Player
    let round: Round
    let holeScores: [HoleScore]?

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateStyle = .medium
        if let date = fmt.date(from: round.playedAt) {
            return display.string(from: date)
        }
        return round.playedAt
    }

    private var netVsParLabel: String {
        let v = round.netVsPar
        if v == 0 { return "Even" }
        return v > 0 ? "+\(v)" : "\(v)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THC Homie Cup")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(player.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
            .background(Color.green)

            // Score summary
            HStack(spacing: 0) {
                scoreItem(label: "Gross", value: "\(round.grossScore)")
                Divider().frame(height: 50)
                scoreItem(label: "Net", value: "\(round.netScore)")
                Divider().frame(height: 50)
                scoreItem(label: "vs Par", value: netVsParLabel)
                Divider().frame(height: 50)
                if let points = round.points {
                    scoreItem(label: "Points", value: "\(points)", accent: true)
                }
            }
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))

            // Course + date
            VStack(spacing: 6) {
                Text(round.courseName)
                    .font(.headline)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))

            // Per-hole grid (if available)
            if let holeScores, !holeScores.isEmpty {
                holeGrid(holeScores: holeScores.sorted { $0.holeNumber < $1.holeNumber })
            }

            // Footer
            Text("thc.golf")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
        }
        .frame(width: 390)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private func scoreItem(label: String, value: String, accent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(accent ? .green : .primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func holeGrid(holeScores: [HoleScore]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 9), spacing: 1) {
            ForEach(holeScores) { hs in
                VStack(spacing: 1) {
                    Text("\(hs.holeNumber)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(hs.strokes)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemBackground))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
