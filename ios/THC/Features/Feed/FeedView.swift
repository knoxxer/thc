import SwiftUI
import Shared

/// Main feed tab — shows upcoming rounds, milestones, weekly recap, and recent rounds.
struct FeedView: View {
    @Bindable var viewModel: FeedViewModel
    @State private var showPostUpcoming = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Post upcoming round button
                Button { showPostUpcoming = true } label: {
                    Label("Post an upcoming round", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(dash: [6])).foregroundStyle(.tertiary))
                }

                // Upcoming rounds
                ForEach(viewModel.upcomingRounds) { ur in
                    UpcomingRoundCardView(
                        round: ur,
                        rsvps: viewModel.rsvpsByRound[ur.id] ?? [],
                        players: viewModel.playersByID,
                        currentPlayerId: viewModel.player.id,
                        onRsvp: { status in Task { await viewModel.rsvp(upcomingRoundId: ur.id, status: status) } }
                    )
                }

                // Weekly recap
                if let recap = viewModel.weeklyRecap {
                    WeeklyRecapCardView(recap: recap)
                }

                // Milestones
                ForEach(viewModel.milestones) { milestone in
                    MilestoneCardView(milestone: milestone)
                }

                // Feed cards
                if viewModel.feedRounds.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("No rounds yet", systemImage: "sportscourt", description: Text("Rounds will appear here as they're posted"))
                } else {
                    ForEach(viewModel.feedRounds) { fr in
                        FeedCardView(
                            feedRound: fr,
                            reactions: viewModel.reactionsByRound[fr.round.id] ?? [],
                            comments: viewModel.commentsByRound[fr.round.id] ?? [],
                            players: viewModel.playersByID,
                            currentPlayerId: viewModel.player.id,
                            onReact: { emoji in Task { await viewModel.toggleReaction(roundId: fr.round.id, emoji: emoji); await viewModel.loadFeed() } },
                            onComment: { body in Task { await viewModel.addComment(roundId: fr.round.id, body: body); await viewModel.loadFeed() } }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NotificationBellView(viewModel: viewModel)
            }
        }
        .refreshable {
            await viewModel.loadFeed()
            await viewModel.loadNotifications()
        }
        .task {
            await viewModel.loadFeed()
            await viewModel.loadNotifications()
        }
        .sheet(isPresented: $showPostUpcoming) {
            PostUpcomingRoundView(
                onPost: { courseName, teeTime, notes in
                    Task {
                        await viewModel.postUpcomingRound(courseName: courseName, teeTime: teeTime, notes: notes)
                        await viewModel.loadFeed()
                    }
                    showPostUpcoming = false
                }
            )
            .presentationDetents([.medium])
        }
    }
}
