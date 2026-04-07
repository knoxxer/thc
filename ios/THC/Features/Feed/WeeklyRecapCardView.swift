import SwiftUI
import Shared

struct WeeklyRecapCardView: View {
    let recap: WeeklyRecap

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📊 Week in Review (\(recap.weekLabel))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)

            Text("\(recap.roundsPosted) round\(recap.roundsPosted == 1 ? "" : "s") posted")
                .font(.subheadline)

            if let best = recap.bestRound {
                HStack(spacing: 0) {
                    Text("Best: ").font(.subheadline)
                    Text(best.playerName).font(.subheadline.weight(.medium))
                    Text(" — \(best.courseName) (").font(.subheadline)
                    Text("\(best.points) pts").font(.subheadline.weight(.medium)).foregroundStyle(.orange)
                    Text(")").font(.subheadline)
                }
            }

            if let mover = recap.biggestMover {
                HStack(spacing: 0) {
                    Text("Most active: ").font(.subheadline)
                    Text(mover.playerName).font(.subheadline.weight(.medium))
                    Text(" → #\(mover.rank)").font(.subheadline)
                }
            }

            HStack(spacing: 0) {
                Text("\(recap.totalPoints)").font(.subheadline.weight(.medium)).foregroundStyle(.orange)
                Text(" total points earned").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.green.opacity(0.15)))
    }
}
