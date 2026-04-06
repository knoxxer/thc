import SwiftUI
import Shared

/// Tab 1: Season leaderboard with pull-to-refresh, eligibility badges, and player drill-down.
struct LeaderboardView: View {
    let player: Player

    @State private var viewModel: StandingsViewModel
    @State private var selectedStanding: SeasonStanding?

    init(player: Player, syncService: SyncServiceProviding) {
        self.player = player
        _viewModel = State(initialValue: StandingsViewModel(syncService: syncService))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.eligibleStandings.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.eligibleStandings.isEmpty {
                errorView(message: error)
            } else {
                standingsList
            }
        }
        .navigationTitle(viewModel.season?.name ?? "Standings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                liveFeedButton
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $selectedStanding) { standing in
            playerDetailSheet(for: standing)
        }
    }

    // MARK: - Standings List

    private var standingsList: some View {
        List {
            if !viewModel.eligibleStandings.isEmpty {
                Section {
                    eligibleRows
                } header: {
                    seasonHeader
                }
            }

            if !viewModel.ineligibleStandings.isEmpty {
                Section {
                    ineligibleRows
                } header: {
                    Text("Not Yet Eligible")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var eligibleRows: some View {
        ForEach(Array(viewModel.eligibleStandings.enumerated()), id: \.element.id) { index, standing in
            StandingRow(
                rank: index + 1,
                standing: standing,
                isCurrentUser: standing.playerId == player.id
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedStanding = standing
            }
        }
    }

    private var ineligibleRows: some View {
        ForEach(viewModel.ineligibleStandings) { standing in
            StandingRow(
                rank: nil,
                standing: standing,
                isCurrentUser: standing.playerId == player.id
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedStanding = standing
            }
        }
    }

    // MARK: - Season Header

    private var seasonHeader: some View {
        HStack {
            if let season = viewModel.season {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top \(season.topNRounds) of \(season.minRounds)+ rounds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("PTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .textCase(nil)
        .padding(.vertical, 2)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading standings…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var liveFeedButton: some View {
        NavigationLink {
            LiveRoundFeedView()
        } label: {
            Image(systemName: "antenna.radiowaves.left.and.right")
        }
    }

    // MARK: - Sheet

    private func playerDetailSheet(for standing: SeasonStanding) -> some View {
        NavigationStack {
            PlayerDetailView(
                playerId: standing.playerId,
                playerName: standing.playerName,
                playerSlug: standing.playerSlug,
                handicapIndex: standing.handicapIndex,
                viewModel: viewModel
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedStanding = nil }
                }
            }
        }
    }
}

// MARK: - StandingRow

private struct StandingRow: View {
    let rank: Int?
    let standing: SeasonStanding
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Group {
                if let rank {
                    Text("\(rank)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(rankColor(rank))
                        .frame(width: 28, alignment: .center)
                } else {
                    Image(systemName: "minus")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, alignment: .center)
                }
            }

            // Avatar placeholder
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(standing.playerName.prefix(1).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

            // Name + info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(standing.playerName)
                        .font(.subheadline.weight(isCurrentUser ? .semibold : .regular))
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if let hcp = standing.handicapIndex {
                        Text("HCP \(hcp, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(standing.totalRounds) rds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !standing.isEligible {
                        Text("Ineligible")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Points
            Text("\(standing.bestNPoints)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(standing.isEligible ? .primary : .secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .background(isCurrentUser ? Color.accentColor.opacity(0.04) : .clear)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .secondary
        }
    }
}
