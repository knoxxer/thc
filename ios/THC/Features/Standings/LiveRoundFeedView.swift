import SwiftUI
import Shared

/// Real-time feed of active rounds from all players.
/// Subscribes to `live_rounds` via Supabase Realtime.
struct LiveRoundFeedView: View {
    @State private var liveRounds: [LiveRound] = []
    @State private var isLoading: Bool = true
    @State private var socialService: SocialServiceProviding?

    // Allow injection for testing / previews
    let socialServiceProvider: (() -> SocialServiceProviding)?

    init(socialServiceProvider: (() -> SocialServiceProviding)? = nil) {
        self.socialServiceProvider = socialServiceProvider
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading live rounds…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if liveRounds.isEmpty {
                emptyState
            } else {
                liveList
            }
        }
        .navigationTitle("Live Rounds")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startListening()
        }
    }

    // MARK: - List

    private var liveList: some View {
        List(liveRounds) { liveRound in
            LiveRoundRow(liveRound: liveRound)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            // Pull-to-refresh re-initiates the subscription
            await startListening()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Active Rounds")
                .font(.title3.weight(.semibold))
            Text("When players start a round, their progress will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subscription

    private func startListening() async {
        isLoading = true
        let service = socialServiceProvider?() ?? SocialService(supabase: SupabaseClientProvider.shared)
        socialService = service

        isLoading = false
        for await rounds in service.liveRoundsFeed() {
            liveRounds = rounds.sorted { $0.startedAt > $1.startedAt }
        }
    }
}

// MARK: - LiveRoundRow

private struct LiveRoundRow: View {
    let liveRound: LiveRound

    private var scoreLabel: String {
        let s = liveRound.currentScore
        if s == 0 { return "E" }
        return s > 0 ? "+\(s)" : "\(s)"
    }

    private var scoreColor: Color {
        let s = liveRound.currentScore
        if s < 0 { return .green }
        if s > 0 { return .red }
        return .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing indicator
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(liveRound.courseName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Hole \(liveRound.currentHole)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if liveRound.thruHole > 0 {
                        Text("Thru \(liveRound.thruHole)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(liveRound.startedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(scoreLabel)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 4)
    }
}
