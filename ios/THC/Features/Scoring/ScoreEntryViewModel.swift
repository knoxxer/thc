import Foundation
import Observation
import Shared

/// Drives both the post-round form (PostRoundView) and live per-hole scoring.
@Observable
final class ScoreEntryViewModel: @unchecked Sendable {

    // MARK: - Post-Round Entry Fields

    var playedAt: Date = .now
    var courseName: String = ""
    var par: Int = 72
    var grossScore: Int?
    var courseHandicap: Int?

    // MARK: - Computed Values

    /// Net score = gross score − course handicap.
    var netScore: Int? {
        guard let gross = grossScore, let hcp = courseHandicap else { return nil }
        return gross - hcp
    }

    /// Net vs par = net score − par. Negative values mean under par.
    var netVsPar: Int? {
        guard let net = netScore else { return nil }
        return net - par
    }

    /// Points awarded for this round using the THC scoring formula (see `PointsCalculator`).
    var points: Int? {
        guard let nvp = netVsPar else { return nil }
        return PointsCalculator.calculatePoints(netVsPar: nvp)
    }

    // MARK: - Validation

    var validationError: String? {
        if courseName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Course name is required."
        }
        guard let gross = grossScore else {
            return "Gross score is required."
        }
        if gross < 18 || gross > 200 {
            return "Gross score must be between 18 and 200."
        }
        guard let hcp = courseHandicap else {
            return "Course handicap is required."
        }
        if hcp < 0 || hcp > 54 {
            return "Course handicap must be between 0 and 54."
        }
        return nil
    }

    var canSubmit: Bool {
        validationError == nil && !isSubmitting
    }

    // MARK: - Submit State

    private(set) var isSubmitting: Bool = false
    private(set) var submitResult: SubmitResult?

    enum SubmitResult: Equatable {
        case success(points: Int)
        case error(String)
    }

    // MARK: - Dependencies

    private let player: Player
    private let season: Season
    private let offlineStorage: OfflineStorageProviding
    private let syncService: SyncServiceProviding

    init(
        player: Player,
        season: Season,
        offlineStorage: OfflineStorageProviding,
        syncService: SyncServiceProviding
    ) {
        self.player = player
        self.season = season
        self.offlineStorage = offlineStorage
        self.syncService = syncService
    }

    // MARK: - Submission

    /// Saves the round offline and attempts immediate sync.
    func submitPostRound() async {
        guard canSubmit,
              let gross = grossScore,
              let hcp = courseHandicap,
              let net = netScore,
              let nvp = netVsPar,
              let pts = points
        else { return }

        isSubmitting = true
        submitResult = nil
        defer { isSubmitting = false }

        // Format date as "YYYY-MM-DD"
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let playedAtString = dateFmt.string(from: playedAt)

        let round = LocalRound(
            id: UUID(),
            playerId: player.id,
            seasonId: season.id,
            playedAt: playedAtString,
            courseName: courseName.trimmingCharacters(in: .whitespaces),
            par: par,
            grossScore: gross,
            courseHandicap: hcp,
            points: pts,
            source: "app",
            syncedToSupabase: false,
            holeScores: [],
            createdAt: Date()
        )

        do {
            try offlineStorage.saveRound(round)
            // Attempt immediate sync (no-op / silently fails if offline).
            _ = try? await syncService.syncPendingRounds()
            submitResult = .success(points: pts)
        } catch {
            submitResult = .error(error.localizedDescription)
        }
    }

    /// Reset form to defaults (call after successful submit).
    func reset() {
        playedAt = .now
        courseName = ""
        par = 72
        grossScore = nil
        courseHandicap = nil
        submitResult = nil
    }
}
