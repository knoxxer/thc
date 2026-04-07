import SwiftUI
import Shared

struct ReactionBarView: View {
    let reactions: [RoundReaction]
    let currentPlayerId: UUID
    let onReact: (String) -> Void

    @State private var showPicker = false

    private static let emojiOptions = ["⛳", "🔥", "🏌️", "💀", "🎯", "👏", "🤮", "😤"]

    private var grouped: [(emoji: String, count: Int, isMine: Bool)] {
        var map: [String: (count: Int, isMine: Bool)] = [:]
        for r in reactions {
            let existing = map[r.emoji] ?? (count: 0, isMine: false)
            map[r.emoji] = (
                count: existing.count + 1,
                isMine: existing.isMine || r.playerId == currentPlayerId
            )
        }
        return map.map { (emoji: $0.key, count: $0.value.count, isMine: $0.value.isMine) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(grouped, id: \.emoji) { group in
                Button { onReact(group.emoji) } label: {
                    HStack(spacing: 3) {
                        Text(group.emoji).font(.caption)
                        Text("\(group.count)").font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(group.isMine ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1),
                                in: Capsule())
                    .overlay(Capsule().strokeBorder(group.isMine ? Color.orange.opacity(0.4) : Color.clear))
                }
                .buttonStyle(.plain)
            }

            Button { showPicker.toggle() } label: {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.secondary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .top) {
                HStack(spacing: 4) {
                    ForEach(Self.emojiOptions, id: \.self) { emoji in
                        Button {
                            onReact(emoji)
                            showPicker = false
                        } label: {
                            Text(emoji).font(.title3)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}
