import Foundation

/// Mirrors the `seasons` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct Season: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let startsAt: Date
    public let endsAt: Date
    public let isActive: Bool
    public let minRounds: Int
    public let topNRounds: Int
    public let createdAt: Date
}
