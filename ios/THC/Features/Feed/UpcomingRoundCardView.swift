import SwiftUI
import Shared

struct UpcomingRoundCardView: View {
    let round: UpcomingRound
    let rsvps: [UpcomingRoundRsvp]
    let players: [UUID: Player]
    let currentPlayerId: UUID
    let onRsvp: (String) -> Void

    private var myRsvp: UpcomingRoundRsvp? {
        rsvps.first { $0.playerId == currentPlayerId }
    }

    private var goingPlayers: [String] {
        rsvps.filter { $0.status == "in" }.compactMap { players[$0.playerId]?.displayName }
    }

    private var maybePlayers: [String] {
        rsvps.filter { $0.status == "maybe" }.compactMap { players[$0.playerId]?.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.green)

            Text(round.courseName)
                .font(.headline)

            Text(round.teeTime.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Posted by \(players[round.playerId]?.displayName ?? "Unknown")")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let notes = round.notes {
                Text(""\(notes)"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // RSVP buttons
            HStack(spacing: 8) {
                rsvpButton(status: "in", label: "I'm In", activeColor: .green)
                rsvpButton(status: "maybe", label: "Maybe", activeColor: .yellow)
                rsvpButton(status: "out", label: "Can't", activeColor: .red)
            }

            if !goingPlayers.isEmpty {
                Text("\(goingPlayers.count) going: \(goingPlayers.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.8))
            }
            if !maybePlayers.isEmpty {
                Text("\(maybePlayers.count) maybe: \(maybePlayers.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.green.opacity(0.2)))
    }

    @ViewBuilder
    private func rsvpButton(status: String, label: String, activeColor: Color) -> some View {
        let isActive = myRsvp?.status == status
        Button { onRsvp(status) } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? activeColor.opacity(0.15) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? activeColor.opacity(0.4) : Color.secondary.opacity(0.2)))
                .foregroundStyle(isActive ? activeColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
