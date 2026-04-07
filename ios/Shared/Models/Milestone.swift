import Foundation

/// Computed milestone — not stored in DB. Derived from rounds and standings.
public struct Milestone: Identifiable, Sendable {
    public var id: String { "\(type):\(playerName)" }

    /// "season_best" | "streak" | "first_round" | "eligibility" | "points_milestone"
    public let type: String
    public let title: String
    public let description: String
    public let playerName: String
    public let playerSlug: String
    public let timestamp: Date

    public init(type: String, title: String, description: String, playerName: String, playerSlug: String, timestamp: Date) {
        self.type = type; self.title = title; self.description = description
        self.playerName = playerName; self.playerSlug = playerSlug; self.timestamp = timestamp
    }
}

/// Computed weekly recap — not stored in DB.
public struct WeeklyRecap: Sendable {
    public let weekLabel: String
    public let roundsPosted: Int
    public let bestRound: BestRound?
    public let totalPoints: Int
    public let biggestMover: BiggestMover?

    public struct BestRound: Sendable {
        public let playerName: String
        public let courseName: String
        public let points: Int
    }

    public struct BiggestMover: Sendable {
        public let playerName: String
        public let rank: Int
    }
}
