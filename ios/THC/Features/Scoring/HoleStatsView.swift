import SwiftUI

/// Optional hole stats: putts, fairway hit, GIR.
/// Used inside LiveScoringView. Bound to `HoleEntryState`.
struct HoleStatsView: View {
    @Binding var entry: HoleEntryState

    var body: some View {
        VStack(spacing: 16) {
            // Putts
            puttsRow

            Divider()

            // FIR (Fairway in Regulation)
            firRow

            Divider()

            // GIR
            girRow
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Putts

    private var puttsRow: some View {
        HStack {
            Label("Putts", systemImage: "figure.golf")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Button {
                    let current = entry.putts ?? 2
                    if current > 0 {
                        entry.putts = current - 1
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text(entry.putts.map { "\($0)" } ?? "—")
                    .font(.headline.monospacedDigit())
                    .frame(width: 30, alignment: .center)

                Button {
                    entry.putts = (entry.putts ?? 1) + 1
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                if entry.putts != nil {
                    Button {
                        entry.putts = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - FIR

    private var firRow: some View {
        HStack {
            Label("Fairway", systemImage: "arrow.up.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                ForEach(FIROption.allCases) { option in
                    firButton(option: option)
                }
            }
        }
    }

    private func firButton(option: FIROption) -> some View {
        let isSelected = entry.fairwayHit == option.rawValue
        return Button {
            entry.fairwayHit = isSelected ? nil : option.rawValue
        } label: {
            Text(option.label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? option.color : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.12), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - GIR

    private var girRow: some View {
        HStack {
            Label("GIR", systemImage: "flag.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                girButton(label: "Hit", value: true)
                girButton(label: "Missed", value: false)
            }
        }
    }

    private func girButton(label: String, value: Bool) -> some View {
        let isSelected = entry.greenInRegulation == value
        return Button {
            entry.greenInRegulation = isSelected ? nil : value
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? (value ? Color.green : Color.red) : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.12), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FIR Option

private enum FIROption: String, CaseIterable, Identifiable {
    case hit = "hit"
    case left = "left"
    case right = "right"
    case na = "na"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hit: return "Hit"
        case .left: return "Left"
        case .right: return "Right"
        case .na: return "N/A"
        }
    }

    var color: Color {
        switch self {
        case .hit: return .green
        case .left: return .orange
        case .right: return .orange
        case .na: return .secondary
        }
    }
}
