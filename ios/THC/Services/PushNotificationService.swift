import Foundation
import UserNotifications

// MARK: - Event Types

struct StandingsChangeEvent {
    let previousRank: Int
    let newRank: Int
    let playerId: UUID
    let playerName: String
}

struct EligibilityEvent {
    let playerId: UUID
    let currentRounds: Int
    let minRounds: Int
}

// MARK: - Protocol

protocol UNUserNotificationCenterProviding: Sendable {
    func requestAuthorization(options: Any) async throws -> Bool
}

// MARK: - Implementation

@Observable
final class PushNotificationService: @unchecked Sendable {
    private let supabase: SupabaseClientProviding
    private let notificationCenter: UNUserNotificationCenterProviding

    private(set) var isPushEnabled: Bool = false

    init(
        supabase: SupabaseClientProviding,
        notificationCenter: UNUserNotificationCenterProviding
    ) {
        self.supabase = supabase
        self.notificationCenter = notificationCenter
    }

    // MARK: - Push Permissions

    func requestPushPermissions() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: UNAuthorizationOptions([.alert, .badge, .sound])
            )
            isPushEnabled = granted
        } catch {
            isPushEnabled = false
        }
    }

    // MARK: - Standings Change

    func handleStandingsChange(_ event: StandingsChangeEvent) async throws {
        guard event.newRank == 1 else { return }
        let payload = PushEventPayload(
            type: "standings_change",
            playerId: event.playerId.uuidString.lowercased(),
            playerName: event.playerName,
            detail: "Rank changed to \(event.newRank)"
        )
        try await supabase.client
            .from("push_events")
            .insert(payload)
            .execute()
    }

    // MARK: - Eligibility

    func handleEligibilityApproaching(_ event: EligibilityEvent) async throws {
        guard event.currentRounds == event.minRounds - 1 else { return }
        let payload = PushEventPayload(
            type: "eligibility_reminder",
            playerId: event.playerId.uuidString.lowercased(),
            playerName: nil,
            detail: "Rounds: \(event.currentRounds)/\(event.minRounds)"
        )
        try await supabase.client
            .from("push_events")
            .insert(payload)
            .execute()
    }
}

// MARK: - Payloads

private struct PushEventPayload: Encodable {
    let type: String
    let playerId: String
    let playerName: String?
    let detail: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case playerId = "player_id"
        case playerName = "player_name"
        case detail
    }
}
