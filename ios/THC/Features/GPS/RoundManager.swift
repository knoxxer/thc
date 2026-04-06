import Foundation
import CoreLocation
import Observation
import Shared

// MARK: - Live Round Broadcasting Protocol (Fix #11)

/// Abstracts live round CRUD so RoundManager doesn't depend on Supabase directly.
protocol LiveRoundBroadcasting: Sendable {
    func startLiveRound(
        id: UUID, playerId: UUID, courseName: String,
        courseDataId: UUID?, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws

    func updateLiveRound(
        id: UUID, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws

    func deleteLiveRound(id: UUID) async throws
}

/// Orchestrates an active round: hole progression, auto-advance, score accumulation,
/// live round broadcasting to Supabase, and offline persistence.
@Observable
final class RoundManager: @unchecked Sendable {

    // MARK: - RoundState

    enum RoundState: Equatable {
        case notStarted
        /// `hole`: the hole currently being played (1-indexed)
        /// `score`: running strokes-vs-par (negative = under)
        case active(hole: Int, score: Int)
        case finished

        static func == (lhs: RoundState, rhs: RoundState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted): return true
            case (.active(let h1, let s1), .active(let h2, let s2)): return h1 == h2 && s1 == s2
            case (.finished, .finished): return true
            default: return false
            }
        }
    }

    // MARK: - HoleScoreEntry

    struct HoleScoreEntry {
        var strokes: Int
        var putts: Int?
        var fairwayHit: String?
        var greenInRegulation: Bool?
    }

    // MARK: - Public State

    private(set) var state: RoundState = .notStarted
    private(set) var currentHole: Int = 1
    private(set) var courseDetail: CourseDetail?
    private(set) var holeScores: [Int: HoleScoreEntry] = [:]

    // MARK: - Private

    private let player: Player
    private let season: Season
    private let locationManager: LocationManager
    private let offlineStorage: OfflineStorageProviding
    private let syncService: SyncServiceProviding
    private let liveRoundBroadcaster: LiveRoundBroadcasting

    private var localRoundId: UUID = UUID()
    private var liveRoundId: UUID?
    private var locationTask: Task<Void, Never>?
    private var totalStrokes: Int = 0
    private var parSoFar: Int = 0

    // MARK: - Init

    init(
        courseDetail: CourseDetail,
        player: Player,
        season: Season,
        locationManager: LocationManager,
        offlineStorage: OfflineStorageProviding,
        syncService: SyncServiceProviding,
        liveRoundBroadcaster: LiveRoundBroadcasting
    ) {
        self.courseDetail = courseDetail
        self.player = player
        self.season = season
        self.locationManager = locationManager
        self.offlineStorage = offlineStorage
        self.syncService = syncService
        self.liveRoundBroadcaster = liveRoundBroadcaster
    }

    // MARK: - Round Lifecycle

    func startRound() async {
        guard state == .notStarted else { return }
        state = .active(hole: 1, score: 0)
        currentHole = 1
        localRoundId = UUID()

        // Persist a stub round immediately so that saveHoleScore calls during the round
        // can append to an existing LocalRound. Final score fields are updated in finishRound().
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let stub = LocalRound(
            id: localRoundId,
            playerId: player.id,
            seasonId: season.id,
            playedAt: dateFmt.string(from: Date()),
            courseName: courseDetail?.course.name ?? "",
            par: courseDetail?.course.par ?? 72,
            grossScore: 0,
            courseHandicap: 0,
            points: 0,
            source: "app",
            syncedToSupabase: false,
            holeScores: [],
            createdAt: Date()
        )
        try? offlineStorage.saveRound(stub)

        locationManager.startRoundTracking()
        startAutoAdvanceTask()

        // Broadcast live round
        do {
            try await broadcastLiveRoundStart()
        } catch {
            // Non-fatal — live feed is best-effort
        }
    }

    func recordHoleScore(_ entry: HoleScoreEntry) async {
        guard case .active(let holeNum, _) = state else { return }

        holeScores[holeNum] = entry

        // Update running totals
        let holePar = courseDetail?.holes.first { $0.holeNumber == holeNum }?.par ?? 4
        totalStrokes += entry.strokes
        parSoFar += holePar

        let newScoreVsPar = totalStrokes - parSoFar
        let nextHole = holeNum + 1
        let totalHoles = courseDetail?.holes.count ?? 18

        if nextHole <= totalHoles {
            state = .active(hole: nextHole, score: newScoreVsPar)
            currentHole = nextHole
        } else {
            // Completed last hole — stay on active state until finishRound() is called
            state = .active(hole: holeNum, score: newScoreVsPar)
        }

        // Save hole score offline
        let localHoleScore = LocalHoleScore(
            id: UUID(),
            holeNumber: holeNum,
            strokes: entry.strokes,
            putts: entry.putts,
            fairwayHit: entry.fairwayHit,
            greenInRegulation: entry.greenInRegulation
        )
        try? offlineStorage.saveHoleScore(localHoleScore, roundId: localRoundId)

        // Update live round
        do {
            try await updateLiveRound(thruHole: holeNum, scoreVsPar: newScoreVsPar)
        } catch {
            // Non-fatal
        }
    }

    func goToHole(_ number: Int) {
        guard case .active(_, let score) = state else { return }
        let totalHoles = courseDetail?.holes.count ?? 18
        guard (1...totalHoles).contains(number) else { return }
        state = .active(hole: number, score: score)
        currentHole = number
    }

    /// Finalise the round, persist it offline, attempt immediate sync, and broadcast deletion
    /// of the live round row. Returns the `LocalRound` that was saved.
    ///
    /// Scoring: netScore = grossScore − courseHandicap; points = PointsCalculator(netVsPar).
    /// `courseHandicap` is floored from `player.handicapIndex` (no USGA slope adjustment on
    /// the app side — the app stores a pre-computed course handicap entered by the user).
    @discardableResult
    func finishRound() async throws -> LocalRound {
        // Fix #22: Guard against finishing a round that was never started.
        guard state != .notStarted else {
            throw RoundManagerError.roundNotStarted
        }

        locationManager.stopRoundTracking()
        locationTask?.cancel()

        let par = courseDetail?.course.par ?? 72
        let grossScore = totalStrokes
        let courseHandicap = player.handicapIndex.map { Int($0) } ?? 0
        let netScore = grossScore - courseHandicap
        let netVsPar = netScore - par
        let points = PointsCalculator.calculatePoints(netVsPar: netVsPar)

        // Update the stub round that was saved in startRound() with the final computed values.
        // The stub already has all hole scores appended via saveHoleScore during play.
        try offlineStorage.finalizeRound(
            id: localRoundId,
            grossScore: grossScore,
            courseHandicap: courseHandicap,
            points: points
        )

        // Build a return value from the now-finalised data (does not insert a second row).
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let localRound = LocalRound(
            id: localRoundId,
            playerId: player.id,
            seasonId: season.id,
            playedAt: dateFmt.string(from: Date()),
            courseName: courseDetail?.course.name ?? "",
            par: par,
            grossScore: grossScore,
            courseHandicap: courseHandicap,
            points: points,
            source: "app",
            syncedToSupabase: false,
            holeScores: [],
            createdAt: Date()
        )

        _ = try? await syncService.syncPendingRounds()

        // Remove live round row
        do {
            try await deleteLiveRound()
        } catch {
            // Non-fatal
        }

        state = .finished
        return localRound
    }

    // MARK: - Distance Calculations

    func currentGreenDistances() -> GreenDistances? {
        guard let coord = locationManager.coordinate,
              let hole = currentHoleData else { return nil }

        guard let lat = hole.greenLat, let lon = hole.greenLon else { return nil }

        let greenCenter = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let approachFrom = coord  // fallback: use user position as approach direction

        return DistanceCalculator.greenDistances(
            userLocation: coord,
            greenCenter: greenCenter,
            greenPolygon: hole.greenPolygon,
            approachFrom: approachFrom
        )
    }

    func currentHazardDistances() -> [HazardInfo] {
        // Hazard distances would come from OSM polygon data stored on CourseHole.
        // For tap-and-save courses with no polygon data, return empty.
        // (Full implementation populates this from CourseDetail.hazards when available)
        return []
    }

    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> Double {
        guard let current = locationManager.coordinate else { return 0 }
        return DistanceCalculator.distanceInYards(from: current, to: coordinate)
    }

    // MARK: - Private Helpers

    private var currentHoleData: CourseHole? {
        courseDetail?.holes.first { $0.holeNumber == currentHole }
    }

    // MARK: - Auto-Advance

    private func startAutoAdvanceTask() {
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in locationManager.locationUpdates {
                await checkAutoAdvance(location: location)
            }
        }
    }

    private func checkAutoAdvance(location: CLLocation) async {
        guard case .active(let holeNum, _) = state else { return }
        let totalHoles = courseDetail?.holes.count ?? 18
        guard holeNum < totalHoles else { return }
        // Only auto-advance after a hole score has been recorded for the current hole
        guard holeScores[holeNum] != nil else { return }

        let nextHole = holeNum + 1
        guard let nextHoleData = courseDetail?.holes.first(where: { $0.holeNumber == nextHole }) else { return }

        // Fix #12: Capture the CURRENT hole's green data, not `currentHoleData`
        // (which would be wrong if recordHoleScore already advanced `currentHole`).
        let scoredHoleData = courseDetail?.holes.first(where: { $0.holeNumber == holeNum })

        let userLoc = location

        // Condition 1: within 30 yards of next tee box
        if let teeLat = nextHoleData.teeLat, let teeLon = nextHoleData.teeLon {
            let teeLoc = CLLocation(latitude: teeLat, longitude: teeLon)
            let distanceMeters = userLoc.distance(from: teeLoc)
            if distanceMeters <= Constants.autoAdvanceThresholdMeters {
                goToHole(nextHole)
                return
            }
        }

        // Condition 2: more than 50 yards from the scored hole's green (fallback)
        if let gLat = scoredHoleData?.greenLat, let gLon = scoredHoleData?.greenLon {
            let greenLoc = CLLocation(latitude: gLat, longitude: gLon)
            let distanceMeters = userLoc.distance(from: greenLoc)
            if distanceMeters > Constants.autoAdvanceFallbackMeters {
                goToHole(nextHole)
            }
        }
    }

    // MARK: - Live Round Broadcasting (via LiveRoundBroadcasting protocol, Fix #11)

    private func broadcastLiveRoundStart() async throws {
        let liveRoundId = UUID()
        self.liveRoundId = liveRoundId

        try await liveRoundBroadcaster.startLiveRound(
            id: liveRoundId,
            playerId: player.id,
            courseName: courseDetail?.course.name ?? "",
            courseDataId: courseDetail?.course.id,
            currentHole: 1,
            thruHole: 0,
            currentScore: 0
        )
    }

    private func updateLiveRound(thruHole: Int, scoreVsPar: Int) async throws {
        guard let liveId = liveRoundId else { return }
        try await liveRoundBroadcaster.updateLiveRound(
            id: liveId,
            currentHole: currentHole,
            thruHole: thruHole,
            currentScore: scoreVsPar
        )
    }

    private func deleteLiveRound() async throws {
        guard let liveId = liveRoundId else { return }
        try await liveRoundBroadcaster.deleteLiveRound(id: liveId)
        self.liveRoundId = nil
    }
}

// MARK: - RoundManager Errors

enum RoundManagerError: LocalizedError {
    case roundNotStarted

    var errorDescription: String? {
        switch self {
        case .roundNotStarted:
            return "Cannot finish a round that has not been started."
        }
    }
}
