import Foundation
import Supabase
import Shared

// MARK: - Protocol

/// Live round feed, reactions, and push notification registration.
protocol SocialServiceProviding: Sendable {
    /// Subscribe to all active live rounds via Supabase Realtime.
    func liveRoundsFeed() -> AsyncStream<[LiveRound]>

    /// Post a reaction (emoji + optional comment) on a completed round.
    func reactToRound(roundId: UUID, emoji: String, comment: String?) async throws

    /// Fetch all reactions for a specific round.
    func getReactions(roundId: UUID) async throws -> [RoundReaction]

    /// Register an APNs device token with Supabase for push notifications.
    func registerForPushNotifications(deviceToken: Data) async throws
}

// MARK: - Errors

enum SocialServiceError: LocalizedError {
    case realtimeNotAvailable
    case tokenRegistrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .realtimeNotAvailable:
            return "Supabase Realtime is not available."
        case .tokenRegistrationFailed(let detail):
            return "Failed to register push token: \(detail)"
        }
    }
}

// MARK: - Implementation

@Observable
final class SocialService: SocialServiceProviding, @unchecked Sendable {
    let supabase: SupabaseClientProviding

    /// Tracks the active Realtime channel so we can unsubscribe on dealloc.
    private var realtimeChannel: RealtimeChannel?

    init(supabase: SupabaseClientProviding) {
        self.supabase = supabase
    }

    deinit {
        realtimeChannel?.unsubscribe()
    }

    // MARK: - SocialServiceProviding

    /// Subscribe to live round updates. Yields the full `live_rounds` table on each change.
    ///
    /// Re-fetching the whole table on every postgres_changes event (rather than applying
    /// incremental updates) keeps the implementation simple and correct. The `live_rounds`
    /// table is tiny (one row per active player) so the extra bandwidth is negligible.
    func liveRoundsFeed() -> AsyncStream<[LiveRound]> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            Task {
                // Fetch the initial snapshot before subscribing to changes.
                let initial: [LiveRound] = (try? await self.supabase.client
                    .from("live_rounds")
                    .select()
                    .execute()
                    .value) ?? []

                continuation.yield(initial)

                // Unsubscribe old channel before creating a new one (Fix #7).
                self.realtimeChannel?.unsubscribe()

                // Subscribe to all changes on live_rounds via Supabase Realtime.
                let channel = self.supabase.client.realtime.channel("public:live_rounds")
                self.realtimeChannel = channel

                channel.on("postgres_changes", filter: .init(event: "*", schema: "public", table: "live_rounds")) { [weak self] _ in
                    guard let self else { return }
                    Task {
                        let updated: [LiveRound] = (try? await self.supabase.client
                            .from("live_rounds")
                            .select()
                            .execute()
                            .value) ?? []
                        continuation.yield(updated)
                    }
                }

                channel.subscribe()

                // Keep the stream alive until the continuation is cancelled.
                await withTaskCancellationHandler {
                    // Suspend indefinitely — updates arrive via the channel callback above.
                    try? await Task.sleep(for: .seconds(Double.greatestFiniteMagnitude))
                } onCancel: {
                    continuation.finish()
                }
            }
        }
    }

    func reactToRound(roundId: UUID, emoji: String, comment: String?) async throws {
        guard let user = await supabase.currentUser else { return }
        let payload = ReactionInsertPayload(
            roundId: roundId,
            playerId: UUID(uuidString: user.id.uuidString) ?? UUID(),
            emoji: emoji,
            comment: comment
        )
        try await supabase.client
            .from("round_reactions")
            .insert(payload)
            .execute()
    }

    func getReactions(roundId: UUID) async throws -> [RoundReaction] {
        let roundIdString = roundId.uuidString.lowercased()
        return try await supabase.client
            .from("round_reactions")
            .select()
            .eq("round_id", value: roundIdString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func registerForPushNotifications(deviceToken: Data) async throws {
        guard let user = await supabase.currentUser else { return }

        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        let payload = PushTokenPayload(
            userId: user.id.uuidString.lowercased(),
            token: tokenString,
            platform: "apns"
        )

        // Upsert so that re-registration after a token rotation is a no-op.
        try await supabase.client
            .from("push_tokens")
            .upsert(payload, onConflict: "user_id,platform")
            .execute()
    }

    // MARK: - Connection Lifecycle

    /// Disconnect the Realtime subscription when the live feed is no longer visible.
    func disconnectLiveFeed() {
        realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }
}

// MARK: - LiveRoundBroadcasting Conformance (Fix #11)

extension SocialService: LiveRoundBroadcasting {
    func startLiveRound(
        id: UUID, playerId: UUID, courseName: String,
        courseDataId: UUID?, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws {
        let payload = LiveRoundInsertPayload(
            id: id.uuidString.lowercased(),
            playerId: playerId.uuidString.lowercased(),
            courseName: courseName,
            courseDataId: courseDataId?.uuidString.lowercased(),
            currentHole: currentHole,
            thruHole: thruHole,
            currentScore: currentScore
        )
        try await supabase.client.from("live_rounds").insert(payload).execute()
    }

    func updateLiveRound(
        id: UUID, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws {
        let update = LiveRoundUpdatePayload(
            currentHole: currentHole,
            thruHole: thruHole,
            currentScore: currentScore
        )
        try await supabase.client
            .from("live_rounds")
            .update(update)
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    func deleteLiveRound(id: UUID) async throws {
        try await supabase.client
            .from("live_rounds")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}

// MARK: - Live Round Payloads

private struct LiveRoundInsertPayload: Encodable {
    let id: String
    let playerId: String
    let courseName: String
    let courseDataId: String?
    let currentHole: Int
    let thruHole: Int
    let currentScore: Int
    enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case courseName = "course_name"
        case courseDataId = "course_data_id"
        case currentHole = "current_hole"
        case thruHole = "thru_hole"
        case currentScore = "current_score"
    }
}

private struct LiveRoundUpdatePayload: Encodable {
    let currentHole: Int
    let thruHole: Int
    let currentScore: Int
    enum CodingKeys: String, CodingKey {
        case currentHole = "current_hole"
        case thruHole = "thru_hole"
        case currentScore = "current_score"
    }
}

// MARK: - Insert Payloads

private struct ReactionInsertPayload: Encodable {
    let roundId: String
    let playerId: String
    let emoji: String
    let comment: String?

    init(roundId: UUID, playerId: UUID, emoji: String, comment: String?) {
        self.roundId = roundId.uuidString.lowercased()
        self.playerId = playerId.uuidString.lowercased()
        self.emoji = emoji
        self.comment = comment
    }

    private enum CodingKeys: String, CodingKey {
        case roundId = "round_id"
        case playerId = "player_id"
        case emoji
        case comment
    }
}

private struct PushTokenPayload: Encodable {
    let userId: String
    let token: String
    let platform: String

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
    }
}
