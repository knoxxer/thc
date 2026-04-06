import Foundation
import SwiftData
import Observation
import Shared

/// Drives the leaderboard and player detail views.
///
/// Sorting rules (matching the web app):
/// 1. Eligible players first, sorted by `bestNPoints` descending.
/// 2. Tiebreaker: lower `bestNetVsPar` wins (better score).
/// 3. Ineligible players listed after eligible, same sort order.
@Observable
final class StandingsViewModel: @unchecked Sendable {
    private(set) var season: Season?
    private(set) var eligibleStandings: [SeasonStanding] = []
    private(set) var ineligibleStandings: [SeasonStanding] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    private let syncService: SyncServiceProviding

    init(syncService: SyncServiceProviding) {
        self.syncService = syncService
    }

    // MARK: - Loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        await fetchData()
        isLoading = false
    }

    func refresh() async {
        error = nil
        await fetchData()
    }

    // MARK: - Player Rounds

    func playerRounds(playerId: UUID) async -> [Round] {
        guard let season else { return [] }
        do {
            let rounds = try await syncService.fetchPlayerRounds(playerId: playerId, seasonId: season.id)
            return rounds.sorted { $0.playedAt > $1.playedAt }
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func fetchData() async {
        do {
            let activeSeason = try await syncService.fetchActiveSeason()
            guard let activeSeason else {
                error = "No active season found."
                return
            }
            season = activeSeason

            let all = try await syncService.fetchStandings(seasonId: activeSeason.id)
            let sorted = sort(standings: all)
            eligibleStandings = sorted.filter { $0.isEligible }
            ineligibleStandings = sorted.filter { !$0.isEligible }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sort(standings: [SeasonStanding]) -> [SeasonStanding] {
        standings.sorted { a, b in
            if a.bestNPoints != b.bestNPoints {
                return a.bestNPoints > b.bestNPoints
            }
            // Lower netVsPar is better (e.g., -2 beats +3)
            return a.bestNetVsPar < b.bestNetVsPar
        }
    }
}
