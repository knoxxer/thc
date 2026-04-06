import Foundation

/// Mirrors the `players` table in Supabase.
/// Decoded using `keyDecodingStrategy: .convertFromSnakeCase`.
public struct Player: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let displayName: String
    public let slug: String
    public let email: String?
    public let ghinNumber: String?
    public let handicapIndex: Double?
    public let handicapUpdatedAt: Date?
    public let avatarUrl: String?
    public let isActive: Bool
    /// "admin" | "contributor"
    public let role: String
    public let authUserId: String?
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        displayName: String,
        slug: String,
        email: String?,
        ghinNumber: String?,
        handicapIndex: Double?,
        handicapUpdatedAt: Date?,
        avatarUrl: String?,
        isActive: Bool,
        role: String,
        authUserId: String?,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.slug = slug
        self.email = email
        self.ghinNumber = ghinNumber
        self.handicapIndex = handicapIndex
        self.handicapUpdatedAt = handicapUpdatedAt
        self.avatarUrl = avatarUrl
        self.isActive = isActive
        self.role = role
        self.authUserId = authUserId
        self.createdAt = createdAt
    }
}
