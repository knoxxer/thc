import SwiftUI
import Shared

struct MilestoneCardView: View {
    let milestone: Milestone

    private var emoji: String {
        switch milestone.type {
        case "season_best": return "🏆"
        case "streak": return "🔥"
        case "first_round": return "👋"
        case "eligibility": return "✅"
        case "points_milestone": return "💯"
        default: return "⭐"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                Text(milestone.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.2)))
    }
}
