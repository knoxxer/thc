import SwiftUI
import Shared

struct FeedCardView: View {
    let feedRound: FeedRound
    let reactions: [RoundReaction]
    let comments: [RoundComment]
    let players: [UUID: Player]
    let currentPlayerId: UUID
    let onReact: (String) -> Void
    let onComment: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                // Avatar
                Circle()
                    .fill(.accent)
                    .frame(width: 36, height: 36)
                    .overlay(Text(String(feedRound.playerName.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 1) {
                    Text(feedRound.playerName)
                        .font(.subheadline.weight(.semibold))
                    Text(feedRound.round.courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatDate(feedRound.round.playedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Score breakdown
            HStack(spacing: 4) {
                Text("\(feedRound.round.grossScore) gross")
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text("\(feedRound.round.netScore) net")
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(formatVsPar(feedRound.round.netVsPar))
                Text("·").foregroundStyle(.tertiary)
                Text("\(feedRound.round.points ?? 0) pts")
                    .foregroundStyle(.orange)
                    .fontWeight(.bold)
            }
            .font(.subheadline)

            // Reactions
            ReactionBarView(
                reactions: reactions,
                currentPlayerId: currentPlayerId,
                onReact: onReact
            )

            // Comments
            CommentSectionView(
                comments: comments,
                players: players,
                onComment: onComment
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return dateStr }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(months[min(month, 12)]) \(day)"
    }

    private func formatVsPar(_ n: Int) -> String {
        n == 0 ? "E" : (n > 0 ? "+\(n)" : "\(n)")
    }
}
