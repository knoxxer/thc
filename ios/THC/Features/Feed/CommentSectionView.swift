import SwiftUI
import Shared

struct CommentSectionView: View {
    let comments: [RoundComment]
    let players: [UUID: Player]
    let onComment: (String) -> Void

    @State private var inputText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(comments) { comment in
                HStack(alignment: .top, spacing: 4) {
                    Text(players[comment.playerId]?.displayName ?? "Unknown")
                        .font(.caption.weight(.medium))
                    Text(comment.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(timeAgo(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                TextField("Add comment...", text: $inputText)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)

                Button("Post") {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    onComment(text)
                    inputText = ""
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
