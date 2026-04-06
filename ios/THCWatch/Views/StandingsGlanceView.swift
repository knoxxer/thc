import SwiftUI
import Shared

/// Top 5 leaderboard glance for Apple Watch.
/// Displays player name and points from the latest standings pushed from the phone.
struct StandingsGlanceView: View {
    @EnvironmentObject private var connectivityService: PhoneConnectivityService

    private var topStandings: [SeasonStanding] {
        Array(connectivityService.standings.prefix(5))
    }

    var body: some View {
        Group {
            if topStandings.isEmpty {
                emptyState
            } else {
                standingsList
            }
        }
        .navigationTitle("Standings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Standings List

    private var standingsList: some View {
        List {
            ForEach(Array(topStandings.enumerated()), id: \.element.id) { index, standing in
                standingRow(rank: index + 1, standing: standing)
                    .listRowBackground(rowBackground(for: index + 1))
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func standingRow(rank: Int, standing: SeasonStanding) -> some View {
        HStack(spacing: 6) {
            rankBadge(rank: rank)

            VStack(alignment: .leading, spacing: 1) {
                Text(standing.playerName)
                    .font(.caption)
                    .fontWeight(rank == 1 ? .bold : .regular)
                    .lineLimit(1)

                if standing.isEligible {
                    Text("\(standing.totalRounds) rounds")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not eligible")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            pointsBadge(points: standing.bestNPoints, rank: rank)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func rankBadge(rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(rankColor(rank).opacity(0.20))
                .frame(width: 22, height: 22)

            Text("\(rank)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(rankColor(rank))
        }
    }

    @ViewBuilder
    private func pointsBadge(points: Int, rank: Int) -> some View {
        Text("\(points)")
            .font(.callout)
            .fontWeight(.black)
            .foregroundStyle(rankColor(rank))
            .monospacedDigit()
    }

    @ViewBuilder
    private func rowBackground(for rank: Int) -> some View {
        if rank == 1 {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.yellow.opacity(0.08))
        } else {
            Color.clear
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.number")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No Standings")
                .font(.headline)

            Text("Open the iPhone app to sync standings")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helpers

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
}

#Preview {
    let service = PhoneConnectivityService()
    // Inject mock data via published property for preview
    NavigationStack {
        StandingsGlanceView()
            .environmentObject(service)
    }
}
