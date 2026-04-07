import Foundation
import Shared

/// Drives the Feed tab — fetches rounds, reactions, comments, upcoming rounds, notifications.
@Observable
final class FeedViewModel: @unchecked Sendable {
    private let socialService: SocialService
    private let syncService: SyncServiceProviding
    let player: Player

    var feedRounds: [FeedRound] = []
    var reactionsByRound: [UUID: [RoundReaction]] = [:]
    var commentsByRound: [UUID: [RoundComment]] = [:]
    var playersByID: [UUID: Player] = [:]
    var upcomingRounds: [UpcomingRound] = []
    var rsvpsByRound: [UUID: [UpcomingRoundRsvp]] = [:]
    var notifications: [AppNotification] = []
    var unreadCount: Int = 0
    var milestones: [Milestone] = []
    var weeklyRecap: WeeklyRecap?
    var isLoading = false
    var error: String?

    init(socialService: SocialService, syncService: SyncServiceProviding, player: Player) {
        self.socialService = socialService
        self.syncService = syncService
        self.player = player
    }

    @MainActor
    func loadFeed() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            guard let season = try await syncService.fetchActiveSeason() else {
                error = "No active season"
                return
            }

            // Fetch rounds
            let rounds = try await socialService.fetchFeedRounds(seasonId: season.id)
            self.feedRounds = rounds

            let roundIds = rounds.map { $0.round.id }

            // Fetch reactions, comments, upcoming in parallel
            async let reactionsTask = socialService.fetchReactionsForRounds(roundIds: roundIds)
            async let commentsTask = socialService.fetchCommentsForRounds(roundIds: roundIds)
            async let upcomingTask = socialService.fetchUpcomingRounds()
            async let standingsTask = syncService.fetchStandings(seasonId: season.id)
            async let playersTask: [Player] = socialService.supabase.client
                .from("players").select().eq("is_active", value: true).execute().value

            let (reactions, comments, upcoming, standings, players) = try await (
                reactionsTask, commentsTask, upcomingTask, standingsTask, playersTask
            )

            // Group reactions and comments by round
            var reactionMap: [UUID: [RoundReaction]] = [:]
            for r in reactions {
                reactionMap[r.roundId, default: []].append(r)
            }
            self.reactionsByRound = reactionMap

            var commentMap: [UUID: [RoundComment]] = [:]
            for c in comments {
                commentMap[c.roundId, default: []].append(c)
            }
            self.commentsByRound = commentMap

            // Players by ID
            var pMap: [UUID: Player] = [:]
            for p in players { pMap[p.id] = p }
            self.playersByID = pMap

            // Upcoming rounds + RSVPs
            self.upcomingRounds = upcoming
            if !upcoming.isEmpty {
                let rsvps = try await socialService.fetchRsvps(upcomingRoundIds: upcoming.map(\.id))
                var rsvpMap: [UUID: [UpcomingRoundRsvp]] = [:]
                for r in rsvps {
                    rsvpMap[r.upcomingRoundId, default: []].append(r)
                }
                self.rsvpsByRound = rsvpMap
            }

            // Milestones
            let roundTuples = rounds.map { fr in
                (round: fr.round as any RoundLike, playerName: fr.playerName, playerSlug: fr.playerSlug)
            }
            let standingTuples = standings.map {
                (playerId: $0.playerId, playerName: $0.playerName, playerSlug: $0.playerSlug,
                 totalRounds: $0.totalRounds, bestNPoints: $0.bestNPoints)
            }
            self.milestones = MilestonesGenerator.generate(
                rounds: roundTuples, standings: standingTuples, minRounds: season.minRounds
            )
            self.weeklyRecap = MilestonesGenerator.weeklyRecap(
                rounds: roundTuples, standings: standingTuples
            )

        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func loadNotifications() async {
        do {
            self.notifications = try await socialService.fetchNotifications()
            self.unreadCount = notifications.filter { !$0.isRead }.count
        } catch {
            // silently fail
        }
    }

    func markAllRead() async {
        try? await socialService.markAllNotificationsRead()
        await loadNotifications()
    }

    func toggleReaction(roundId: UUID, emoji: String) async {
        let existing = reactionsByRound[roundId]?.first {
            $0.emoji == emoji && $0.playerId == player.id
        }
        if let existing {
            try? await supabaseDelete(table: "round_reactions", id: existing.id)
        } else {
            try? await socialService.reactToRound(roundId: roundId, emoji: emoji, comment: nil)
            if let fr = feedRounds.first(where: { $0.round.id == roundId }),
               fr.round.playerId != player.id {
                try? await socialService.createNotification(
                    forPlayerId: fr.round.playerId,
                    type: "reaction",
                    title: "\(player.displayName) reacted \(emoji) to your round",
                    body: nil, link: nil
                )
            }
        }
    }

    func addComment(roundId: UUID, body: String) async {
        let _ = try? await socialService.addComment(roundId: roundId, body: body)
        // Notify round owner
        if let fr = feedRounds.first(where: { $0.round.id == roundId }),
           fr.round.playerId != player.id {
            try? await socialService.createNotification(
                forPlayerId: fr.round.playerId,
                type: "comment",
                title: "\(player.displayName) commented on your round",
                body: String(body.prefix(80)), link: nil
            )
        }
    }

    func postUpcomingRound(courseName: String, teeTime: Date, notes: String?) async {
        try? await socialService.postUpcomingRound(courseName: courseName, teeTime: teeTime, notes: notes)
        try? await socialService.createNotificationForAll(
            excludingPlayerId: player.id,
            type: "upcoming_round",
            title: "Upcoming round at \(courseName)",
            body: teeTime.formatted(date: .abbreviated, time: .shortened),
            link: nil
        )
    }

    func rsvp(upcomingRoundId: UUID, status: String) async {
        try? await socialService.rsvp(upcomingRoundId: upcomingRoundId, status: status)
        // Notify organizer
        if let ur = upcomingRounds.first(where: { $0.id == upcomingRoundId }),
           ur.playerId != player.id {
            try? await socialService.createNotification(
                forPlayerId: ur.playerId,
                type: "rsvp",
                title: "\(player.displayName) RSVP'd \"\(status)\" to your round",
                body: ur.courseName, link: nil
            )
        }
    }

    private func supabaseDelete(table: String, id: UUID) async throws {
        try await socialService.supabase.client
            .from(table)
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}
