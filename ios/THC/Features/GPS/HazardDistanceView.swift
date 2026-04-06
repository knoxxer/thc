import SwiftUI
import Shared

/// Displays hazard distances (carry and front edge) for all hazards on the current hole.
/// Used inside `DistanceOverlay`.
struct HazardDistanceView: View {
    let hazards: [HazardInfo]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(hazards, id: \.name) { hazard in
                HazardRow(hazard: hazard)
            }
        }
    }
}

// MARK: - HazardRow

private struct HazardRow: View {
    let hazard: HazardInfo

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: hazard.name))
                    .font(.caption)
                    .foregroundStyle(hazardColor(for: hazard.name))
                    .frame(width: 16)

                Text(hazard.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", hazard.frontEdge))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("Front")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 1) {
                    Text(String(format: "%.0f", hazard.carry))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(hazardColor(for: hazard.name))
                    Text("Carry")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func iconName(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("water") || lower.contains("lake") || lower.contains("pond") {
            return "drop.fill"
        }
        if lower.contains("bunker") || lower.contains("sand") {
            return "circle.dotted"
        }
        if lower.contains("tree") || lower.contains("forest") {
            return "tree.fill"
        }
        return "exclamationmark.triangle.fill"
    }

    private func hazardColor(for name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("water") || lower.contains("lake") || lower.contains("pond") {
            return .blue
        }
        if lower.contains("bunker") || lower.contains("sand") {
            return .yellow
        }
        return .orange
    }
}

// MARK: - Previews

#Preview {
    HazardDistanceView(hazards: [
        HazardInfo(name: "Water", frontEdge: 145, carry: 162),
        HazardInfo(name: "Bunker", frontEdge: 187, carry: 193)
    ])
    .padding()
    .background(Color(.secondarySystemBackground))
}
