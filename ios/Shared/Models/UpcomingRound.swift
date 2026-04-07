import Foundation

/// Mirrors the `upcoming_rounds` table in Supabase.
public struct UpcomingRound: Codable, Identifiable, Sendable {
    public let id: UUID
    public let playerId: UUID
    public let courseName: String
    public let teeTime: Date
    public let notes: String?
    public let createdAt: Date

    public init(id: UUID, playerId: UUID, courseName: String, teeTime: Date, notes: String?, createdAt: Date) {
        self.id = id; self.playerId = playerId; self.courseName = courseName
        self.teeTime = teeTime; self.notes = notes; self.createdAt = createdAt
    }
}

/// Mirrors the `upcoming_round_rsvps` table in Supabase.
public struct UpcomingRoundRsvp: Codable, Identifiable, Sendable {
    public let id: UUID
    public let upcomingRoundId: UUID
    public let playerId: UUID
    /// "in" | "maybe" | "out"
    public let status: String
    public let createdAt: Date

    public init(id: UUID, upcomingRoundId: UUID, playerId: UUID, status: String, createdAt: Date) {
        self.id = id; self.upcomingRoundId = upcomingRoundId; self.playerId = playerId
        self.status = status; self.createdAt = createdAt
    }
}
