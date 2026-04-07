import Foundation

/// Generates milestone cards and weekly recaps from rounds and standings.
/// Port of the web app's milestones.ts — computed, not stored.
public enum MilestonesGenerator {

    public static func generate(
        rounds: [(round: any RoundLike, playerName: String, playerSlug: String)],
        standings: [(playerId: UUID, playerName: String, playerSlug: String, totalRounds: Int, bestNPoints: Int)],
        minRounds: Int
    ) -> [Milestone] {
        guard !rounds.isEmpty else { return [] }

        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recentRounds = rounds.filter { $0.round.createdAtDate > sevenDaysAgo }
        guard !recentRounds.isEmpty else { return [] }

        var milestones: [Milestone] = []

        // Season best
        let allPoints = rounds.map { $0.round.pointsValue }
        let maxPoints = allPoints.max() ?? 0
        if let bestRound = recentRounds.first(where: { $0.round.pointsValue == maxPoints }), maxPoints > 0 {
            let olderMax = rounds.filter { $0.round.roundId != bestRound.round.roundId }
                .map { $0.round.pointsValue }.max() ?? 0
            if maxPoints > olderMax {
                milestones.append(Milestone(
                    type: "season_best",
                    title: "Season Best Round!",
                    description: "\(bestRound.playerName) posted \(bestRound.round.netScoreValue) net at \(bestRound.round.courseNameValue) — \(maxPoints) pts",
                    playerName: bestRound.playerName,
                    playerSlug: bestRound.playerSlug,
                    timestamp: bestRound.round.createdAtDate
                ))
            }
        }

        // First round
        var roundCounts: [UUID: Int] = [:]
        for r in rounds { roundCounts[r.round.playerIdValue, default: 0] += 1 }
        for r in recentRounds where roundCounts[r.round.playerIdValue] == 1 {
            milestones.append(Milestone(
                type: "first_round",
                title: "Welcome to the Season!",
                description: "\(r.playerName) posted their first round",
                playerName: r.playerName, playerSlug: r.playerSlug,
                timestamp: r.round.createdAtDate
            ))
        }

        // Eligibility
        for s in standings where s.totalRounds == minRounds {
            if let r = recentRounds.first(where: { $0.round.playerIdValue == s.playerId }) {
                milestones.append(Milestone(
                    type: "eligibility",
                    title: "Now Eligible!",
                    description: "\(s.playerName) hit \(minRounds) rounds and is now eligible for the standings",
                    playerName: s.playerName, playerSlug: s.playerSlug,
                    timestamp: r.round.createdAtDate
                ))
            }
        }

        // Points milestones (descending so we show highest crossed)
        let thresholds = [150, 125, 100, 75, 50]
        for s in standings {
            for threshold in thresholds where s.bestNPoints >= threshold {
                let playerRecent = recentRounds.filter { $0.round.playerIdValue == s.playerId }
                let recentPts = playerRecent.reduce(0) { $0 + $1.round.pointsValue }
                if s.bestNPoints - recentPts < threshold {
                    milestones.append(Milestone(
                        type: "points_milestone",
                        title: "\(threshold) Points!",
                        description: "\(s.playerName) hit \(s.bestNPoints) total points this season",
                        playerName: s.playerName, playerSlug: s.playerSlug,
                        timestamp: playerRecent.first?.round.createdAtDate ?? Date()
                    ))
                    break
                }
            }
        }

        // Deduplicate
        var seen: Set<String> = []
        return milestones.filter { m in
            let key = "\(m.type):\(m.playerName)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    public static func weeklyRecap(
        rounds: [(round: any RoundLike, playerName: String, playerSlug: String)],
        standings: [(playerId: UUID, playerName: String, playerSlug: String, totalRounds: Int, bestNPoints: Int)]
    ) -> WeeklyRecap? {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let weekRounds = rounds.filter { $0.round.createdAtDate > sevenDaysAgo }
        guard !weekRounds.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startLabel = formatter.string(from: sevenDaysAgo)
        let endLabel = formatter.string(from: Date())

        var bestRound: WeeklyRecap.BestRound?
        var maxPts = 0
        for r in weekRounds {
            let pts = r.round.pointsValue
            if pts > maxPts {
                maxPts = pts
                bestRound = .init(playerName: r.playerName, courseName: r.round.courseNameValue, points: pts)
            }
        }

        let totalPoints = weekRounds.reduce(0) { $0 + $1.round.pointsValue }

        var biggestMover: WeeklyRecap.BiggestMover?
        if !standings.isEmpty {
            let sorted = standings.sorted { $0.bestNPoints > $1.bestNPoints }
            var weekPts: [UUID: Int] = [:]
            for r in weekRounds { weekPts[r.round.playerIdValue, default: 0] += r.round.pointsValue }
            if let (moverId, _) = weekPts.max(by: { $0.value < $1.value }),
               let rank = sorted.firstIndex(where: { $0.playerId == moverId }),
               let s = sorted.first(where: { $0.playerId == moverId }) {
                biggestMover = .init(playerName: s.playerName, rank: rank + 1)
            }
        }

        return WeeklyRecap(
            weekLabel: "\(startLabel) – \(endLabel)",
            roundsPosted: weekRounds.count,
            bestRound: bestRound,
            totalPoints: totalPoints,
            biggestMover: biggestMover
        )
    }
}

// MARK: - Protocol for abstracting Round access

/// Allows MilestonesGenerator to work with both Round and FeedRound.
public protocol RoundLike {
    var roundId: UUID { get }
    var playerIdValue: UUID { get }
    var courseNameValue: String { get }
    var netScoreValue: Int { get }
    var pointsValue: Int { get }
    var createdAtDate: Date { get }
}

extension Round: RoundLike {
    public var roundId: UUID { id }
    public var playerIdValue: UUID { playerId }
    public var courseNameValue: String { courseName }
    public var netScoreValue: Int { netScore }
    public var pointsValue: Int { points ?? 0 }
    public var createdAtDate: Date { createdAt }
}
