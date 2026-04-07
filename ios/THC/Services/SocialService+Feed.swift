import Foundation
import Supabase
import Shared

// MARK: - Feed Protocol Extension

/// Additional social features: comments, upcoming rounds, notifications, feed data.
protocol FeedServiceProviding: Sendable {
    func fetchFeedRounds(seasonId: UUID, limit: Int) async throws -> [FeedRound]
    func fetchReactionsForRounds(roundIds: [UUID]) async throws -> [RoundReaction]
    func fetchCommentsForRounds(roundIds: [UUID]) async throws -> [RoundComment]

    func addComment(roundId: UUID, body: String) async throws -> RoundComment
    func deleteComment(id: UUID) async throws

    func fetchUpcomingRounds() async throws -> [UpcomingRound]
    func fetchRsvps(upcomingRoundIds: [UUID]) async throws -> [UpcomingRoundRsvp]
    func postUpcomingRound(courseName: String, teeTime: Date, notes: String?) async throws
    func rsvp(upcomingRoundId: UUID, status: String) async throws
    func removeRsvp(id: UUID) async throws

    func fetchNotifications(limit: Int) async throws -> [AppNotification]
    func unreadNotificationCount() async throws -> Int
    func markNotificationRead(id: UUID) async throws
    func markAllNotificationsRead() async throws

    func createNotification(forPlayerId: UUID, type: String, title: String, body: String?, link: String?) async throws
    func createNotificationForAll(excludingPlayerId: UUID, type: String, title: String, body: String?, link: String?) async throws
}

// MARK: - FeedRound (round with embedded player info)

/// A round with player display info attached, for rendering feed cards.
struct FeedRound: Identifiable, Sendable {
    let round: Round
    let playerName: String
    let playerSlug: String
    let playerAvatarUrl: String?

    var id: UUID { round.id }
}

// MARK: - Implementation

extension SocialService: FeedServiceProviding {

    // MARK: - Feed Rounds

    func fetchFeedRounds(seasonId: UUID, limit: Int = 30) async throws -> [FeedRound] {
        struct RoundWithPlayer: Decodable {
            let id: UUID
            let playerId: UUID
            let seasonId: UUID
            let playedAt: String
            let courseName: String
            let teeName: String?
            let courseRating: Double?
            let slopeRating: Double?
            let par: Int
            let grossScore: Int
            let courseHandicap: Int
            let netScore: Int
            let netVsPar: Int
            let points: Int?
            let ghinScoreId: String?
            let source: String
            let enteredBy: String?
            let createdAt: Date
            let player: PlayerEmbed

            struct PlayerEmbed: Decodable {
                let id: UUID
                let displayName: String
                let slug: String
                let avatarUrl: String?
            }

            enum CodingKeys: String, CodingKey {
                case id, par, source, player
                case playerId = "player_id"
                case seasonId = "season_id"
                case playedAt = "played_at"
                case courseName = "course_name"
                case teeName = "tee_name"
                case courseRating = "course_rating"
                case slopeRating = "slope_rating"
                case grossScore = "gross_score"
                case courseHandicap = "course_handicap"
                case netScore = "net_score"
                case netVsPar = "net_vs_par"
                case points
                case ghinScoreId = "ghin_score_id"
                case enteredBy = "entered_by"
                case createdAt = "created_at"
            }
        }

        let rows: [RoundWithPlayer] = try await supabase.client
            .from("rounds")
            .select("*, player:players(id, display_name, slug, avatar_url)")
            .eq("season_id", value: seasonId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { r in
            let round = Round(
                id: r.id, playerId: r.playerId, seasonId: r.seasonId,
                playedAt: r.playedAt, courseName: r.courseName, teeName: r.teeName,
                courseRating: r.courseRating, slopeRating: r.slopeRating, par: r.par,
                grossScore: r.grossScore, courseHandicap: r.courseHandicap,
                netScore: r.netScore, netVsPar: r.netVsPar, points: r.points,
                ghinScoreId: r.ghinScoreId, source: r.source, enteredBy: r.enteredBy,
                createdAt: r.createdAt
            )
            return FeedRound(
                round: round,
                playerName: r.player.displayName,
                playerSlug: r.player.slug,
                playerAvatarUrl: r.player.avatarUrl
            )
        }
    }

    // MARK: - Comments

    func fetchCommentsForRounds(roundIds: [UUID]) async throws -> [RoundComment] {
        guard !roundIds.isEmpty else { return [] }
        let ids = roundIds.map { $0.uuidString.lowercased() }
        return try await supabase.client
            .from("round_comments")
            .select()
            .in("round_id", values: ids)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchReactionsForRounds(roundIds: [UUID]) async throws -> [RoundReaction] {
        guard !roundIds.isEmpty else { return [] }
        let ids = roundIds.map { $0.uuidString.lowercased() }
        return try await supabase.client
            .from("round_reactions")
            .select()
            .in("round_id", values: ids)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(roundId: UUID, body: String) async throws -> RoundComment {
        guard let user = await supabase.currentUser else {
            throw SocialServiceError.realtimeNotAvailable
        }
        let payload = CommentInsertPayload(
            roundId: roundId.uuidString.lowercased(),
            playerId: user.id.uuidString.lowercased(),
            body: body
        )
        return try await supabase.client
            .from("round_comments")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteComment(id: UUID) async throws {
        try await supabase.client
            .from("round_comments")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    // MARK: - Upcoming Rounds

    func fetchUpcomingRounds() async throws -> [UpcomingRound] {
        return try await supabase.client
            .from("upcoming_rounds")
            .select()
            .gte("tee_time", value: ISO8601DateFormatter().string(from: Date()))
            .order("tee_time", ascending: true)
            .execute()
            .value
    }

    func fetchRsvps(upcomingRoundIds: [UUID]) async throws -> [UpcomingRoundRsvp] {
        guard !upcomingRoundIds.isEmpty else { return [] }
        let ids = upcomingRoundIds.map { $0.uuidString.lowercased() }
        return try await supabase.client
            .from("upcoming_round_rsvps")
            .select()
            .in("upcoming_round_id", values: ids)
            .execute()
            .value
    }

    func postUpcomingRound(courseName: String, teeTime: Date, notes: String?) async throws {
        guard let user = await supabase.currentUser else { return }
        let payload = UpcomingRoundInsertPayload(
            playerId: user.id.uuidString.lowercased(),
            courseName: courseName,
            teeTime: ISO8601DateFormatter().string(from: teeTime),
            notes: notes
        )
        try await supabase.client
            .from("upcoming_rounds")
            .insert(payload)
            .execute()
    }

    func rsvp(upcomingRoundId: UUID, status: String) async throws {
        guard let user = await supabase.currentUser else { return }
        let payload = RsvpUpsertPayload(
            upcomingRoundId: upcomingRoundId.uuidString.lowercased(),
            playerId: user.id.uuidString.lowercased(),
            status: status
        )
        try await supabase.client
            .from("upcoming_round_rsvps")
            .upsert(payload, onConflict: "upcoming_round_id,player_id")
            .execute()
    }

    func removeRsvp(id: UUID) async throws {
        try await supabase.client
            .from("upcoming_round_rsvps")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    // MARK: - Notifications

    func fetchNotifications(limit: Int = 30) async throws -> [AppNotification] {
        guard let user = await supabase.currentUser else { return [] }
        // Look up player for this auth user
        let players: [Player] = try await supabase.client
            .from("players")
            .select()
            .eq("auth_user_id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let player = players.first else { return [] }

        return try await supabase.client
            .from("notifications")
            .select()
            .eq("player_id", value: player.id.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func unreadNotificationCount() async throws -> Int {
        guard let user = await supabase.currentUser else { return 0 }
        let players: [Player] = try await supabase.client
            .from("players")
            .select()
            .eq("auth_user_id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let player = players.first else { return 0 }

        let result: [AppNotification] = try await supabase.client
            .from("notifications")
            .select()
            .eq("player_id", value: player.id.uuidString.lowercased())
            .eq("is_read", value: false)
            .execute()
            .value
        return result.count
    }

    func markNotificationRead(id: UUID) async throws {
        try await supabase.client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    func markAllNotificationsRead() async throws {
        guard let user = await supabase.currentUser else { return }
        let players: [Player] = try await supabase.client
            .from("players")
            .select()
            .eq("auth_user_id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let player = players.first else { return }

        try await supabase.client
            .from("notifications")
            .update(["is_read": true])
            .eq("player_id", value: player.id.uuidString.lowercased())
            .eq("is_read", value: false)
            .execute()
    }

    func createNotification(forPlayerId: UUID, type: String, title: String, body: String?, link: String?) async throws {
        let payload = NotificationInsertPayload(
            playerId: forPlayerId.uuidString.lowercased(),
            type: type, title: title, body: body, link: link
        )
        try await supabase.client
            .from("notifications")
            .insert(payload)
            .execute()
    }

    func createNotificationForAll(excludingPlayerId: UUID, type: String, title: String, body: String?, link: String?) async throws {
        let players: [Player] = try await supabase.client
            .from("players")
            .select()
            .eq("is_active", value: true)
            .neq("id", value: excludingPlayerId.uuidString.lowercased())
            .execute()
            .value

        let payloads = players.map {
            NotificationInsertPayload(
                playerId: $0.id.uuidString.lowercased(),
                type: type, title: title, body: body, link: link
            )
        }
        if !payloads.isEmpty {
            try await supabase.client
                .from("notifications")
                .insert(payloads)
                .execute()
        }
    }
}

// MARK: - Encodable Payloads

private struct CommentInsertPayload: Encodable {
    let roundId: String
    let playerId: String
    let body: String
    enum CodingKeys: String, CodingKey {
        case roundId = "round_id"
        case playerId = "player_id"
        case body
    }
}

private struct UpcomingRoundInsertPayload: Encodable {
    let playerId: String
    let courseName: String
    let teeTime: String
    let notes: String?
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case courseName = "course_name"
        case teeTime = "tee_time"
        case notes
    }
}

private struct RsvpUpsertPayload: Encodable {
    let upcomingRoundId: String
    let playerId: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case upcomingRoundId = "upcoming_round_id"
        case playerId = "player_id"
        case status
    }
}

private struct NotificationInsertPayload: Encodable {
    let playerId: String
    let type: String
    let title: String
    let body: String?
    let link: String?
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case type, title, body, link
    }
}
