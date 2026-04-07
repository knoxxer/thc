import SwiftUI
import Shared

/// Floating HUD over the satellite map showing green front/center/back,
/// hazard carry/front, layup target, and dogleg distances.
struct DistanceOverlay: View {
    @Bindable var roundManager: RoundManager
    let onScoreEntryTap: () -> Void
    let onTapAndSaveTap: (() -> Void)?

    private var greenDistances: GreenDistances? {
        roundManager.currentGreenDistances()
    }

    private var hazards: [HazardInfo] {
        roundManager.currentHazardDistances()
    }

    private var holeData: CourseHole? {
        guard case .active(let holeNum, _) = roundManager.state else { return nil }
        return roundManager.courseDetail?.holes.first { $0.holeNumber == holeNum }
    }

    private var currentScoreVsPar: Int {
        if case .active(_, let score) = roundManager.state { return score }
        return 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Distance card
            VStack(spacing: 12) {
                holeInfoRow
                Divider()
                greenDistanceRow
                if !hazards.isEmpty {
                    Divider()
                    HazardDistanceView(hazards: hazards)
                }
                if let tap = onTapAndSaveTap {
                    Divider()
                    tapAndSaveRow(action: tap)
                }
                Divider()
                scoreEntryRow
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Rows

    private var holeInfoRow: some View {
        HStack {
            if let hole = holeData {
                HStack(spacing: 8) {
                    Text("Hole \(hole.holeNumber)")
                        .font(.headline)
                    Text("Par \(hole.par)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let yds = hole.yardage {
                        Text("\(yds) yds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let si = hole.handicap {
                        Text("SI \(si)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            scoreLabel
        }
    }

    private var scoreLabel: some View {
        let s = currentScoreVsPar
        let label = s == 0 ? "E" : (s > 0 ? "+\(s)" : "\(s)")
        return Text(label)
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(s < 0 ? .green : s > 0 ? .red : .primary)
    }

    private var greenDistanceRow: some View {
        Group {
            if let g = greenDistances {
                // Always show Front / Center / Back columns.
                // Front and Back are "—" when no green polygon (OSM data) is available;
                // Center is always a live distance derived from the green pin coordinate.
                HStack(spacing: 0) {
                    distanceBlock(label: "Front", yards: g.front, style: .secondary)
                    Spacer()
                    distanceBlock(label: "Center", yards: g.center, style: .primary)
                    Spacer()
                    distanceBlock(label: "Back", yards: g.back, style: .secondary)
                }
            } else {
                noGreenDataRow
            }
        }
    }

    /// Renders a distance column. When `yards` is nil, shows "—" in place of the number.
    private func distanceBlock(label: String, yards: Double?, style: DistanceStyle) -> some View {
        VStack(spacing: 2) {
            Group {
                if let yards = yards {
                    Text(String(format: "%.0f", yards))
                } else {
                    Text("—")
                }
            }
            .font(style == .primary
                ? .system(size: 36, weight: .bold, design: .rounded).monospacedDigit()
                : .system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(style == .primary ? .primary : .secondary)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    private enum DistanceStyle { case primary, secondary }

    private var noGreenDataRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .foregroundStyle(.orange)
            Text("No green location saved for this hole")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var scoreEntryRow: some View {
        Button(action: onScoreEntryTap) {
            Label("Enter Score", systemImage: "pencil.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func tapAndSaveRow(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Save Green Location", systemImage: "flag.badge.ellipsis")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
}
