import Foundation

/// Mirrors the `notifications` table in Supabase.
/// Named `AppNotification` to avoid collision with `Foundation.Notification`.
public struct AppNotification: Codable, Identifiable, Sendable {
    public let id: UUID
    public let playerId: UUID
    /// "new_round" | "reaction" | "comment" | "rsvp" | "upcoming_round"
    public let type: String
    public let title: String
    public let body: String?
    public let link: String?
    public let isRead: Bool
    public let createdAt: Date

    public init(
        id: UUID, playerId: UUID, type: String, title: String,
        body: String?, link: String?, isRead: Bool, createdAt: Date
    ) {
        self.id = id; self.playerId = playerId; self.type = type; self.title = title
        self.body = body; self.link = link; self.isRead = isRead; self.createdAt = createdAt
    }
}
