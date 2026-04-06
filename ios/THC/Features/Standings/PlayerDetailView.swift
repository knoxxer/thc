import SwiftUI
import Shared

/// Shows a player's profile: handicap, handicap update date, and round history.
struct PlayerDetailView: View {
    // Two initializer paths:
    // 1. From the leaderboard (uses StandingsViewModel for data)
    // 2. From the Profile tab (shows the current user's own data via player object)

    // Path 1 — from leaderboard
    var playerId: UUID?
    var playerName: String?
    var playerSlug: String?
    var handicapIndex: Double?
    var viewModel: StandingsViewModel?

    // Path 2 — from profile tab
    var player: Player?
    var isCurrentUser: Bool = false

    @State private var rounds: [Round] = []
    @State private var isLoading: Bool = false
    @State private var selectedRound: Round?

    // Resolved display values
    private var displayName: String {
        player?.displayName ?? playerName ?? "Player"
    }
    private var displayHandicap: Double? {
        player?.handicapIndex ?? handicapIndex
    }
    private var displayHandicapUpdatedAt: Date? {
        player?.handicapUpdatedAt
    }

    var body: some View {
        List {
            profileSection
            roundsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadRounds() }
        .sheet(item: $selectedRound) { round in
            NavigationStack {
                ShareCardView(round: round, playerName: displayName)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedRound = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(displayName.prefix(1).uppercased())
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))

                    if let hcp = displayHandicap {
                        HStack(spacing: 4) {
                            Text("Handicap Index:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", hcp))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        if let updatedAt = displayHandicapUpdatedAt {
                            Text("Updated \(updatedAt, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("No handicap on file")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var roundsSection: some View {
        Section {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if rounds.isEmpty {
                Text("No rounds this season.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rounds) { round in
                    RoundHistoryRow(round: round)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRound = round
                        }
                }
            }
        } header: {
            Text("Round History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    // MARK: - Data Loading

    private func loadRounds() async {
        let id = playerId ?? player?.id
        guard let id else { return }
        isLoading = true
        if let vm = viewModel {
            rounds = await vm.playerRounds(playerId: id)
        }
        isLoading = false
    }
}

// MARK: - RoundHistoryRow

private struct RoundHistoryRow: View {
    let round: Round

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        // playedAt is a "YYYY-MM-DD" string
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        if let date = dateFmt.date(from: round.playedAt) {
            return formatter.string(from: date)
        }
        return round.playedAt
    }

    private var netVsParLabel: String {
        let v = round.netVsPar
        if v == 0 { return "E" }
        return v > 0 ? "+\(v)" : "\(v)"
    }

    private var pointsColor: Color {
        guard let points = round.points else { return .secondary }
        if points >= 12 { return .green }
        if points >= 9 { return .primary }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(round.courseName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let points = round.points {
                    Text("\(points) pts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pointsColor)
                }
                HStack(spacing: 4) {
                    Text("Net \(round.netScore)")
                        .font(.caption)
                    Text("(\(netVsParLabel))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
