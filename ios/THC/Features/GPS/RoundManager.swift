import Foundation
import CoreLocation
import Observation
import Shared

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
    private let supabase: SupabaseClientProviding

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
        supabase: SupabaseClientProviding
    ) {
        self.courseDetail = courseDetail
        self.player = player
        self.season = season
        self.locationManager = locationManager
        self.offlineStorage = offlineStorage
        self.syncService = syncService
        self.supabase = supabase
    }

    // MARK: - Round Lifecycle

    func startRound() async {
        guard state == .notStarted else { return }
        state = .active(hole: 1, score: 0)
        currentHole = 1
        localRoundId = UUID()

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

    @discardableResult
    func finishRound() async throws -> LocalRound {
        locationManager.stopRoundTracking()
        locationTask?.cancel()

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let playedAtString = dateFmt.string(from: Date())

        let par = courseDetail?.course.par ?? 72
        let grossScore = totalStrokes
        let courseHandicap = player.handicapIndex.map { Int($0) } ?? 0
        let netScore = grossScore - courseHandicap
        let netVsPar = netScore - par
        let points = PointsCalculator.calculatePoints(netVsPar: netVsPar)

        let localRound = LocalRound(
            id: localRoundId,
            playerId: player.id,
            seasonId: season.id,
            playedAt: playedAtString,
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

        try offlineStorage.saveRound(localRound)
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

        let userLoc = location

        // Condition 1: within 30 yards of next tee box
        if let teeLat = nextHoleData.teeLat, let teeLon = nextHoleData.teeLon {
            let teeLoc = CLLocation(latitude: teeLat, longitude: teeLon)
            let distanceMeters = userLoc.distance(from: teeLoc)
            if distanceMeters <= 27.4 {  // 30 yards in meters
                goToHole(nextHole)
                return
            }
        }

        // Condition 2: more than 50 yards from current green (fallback)
        if let currHoleData = currentHoleData,
           let gLat = currHoleData.greenLat, let gLon = currHoleData.greenLon {
            let greenLoc = CLLocation(latitude: gLat, longitude: gLon)
            let distanceMeters = userLoc.distance(from: greenLoc)
            if distanceMeters > 45.7 {  // 50 yards in meters
                goToHole(nextHole)
            }
        }
    }

    // MARK: - Live Round Broadcasting

    private func broadcastLiveRoundStart() async throws {
        let liveRoundId = UUID()
        self.liveRoundId = liveRoundId

        struct LiveRoundInsert: Encodable {
            let id: String
            let playerId: String
            let courseName: String
            let courseDataId: String?
            let currentHole: Int
            let thruHole: Int
            let currentScore: Int
            enum CodingKeys: String, CodingKey {
                case id
                case playerId = "player_id"
                case courseName = "course_name"
                case courseDataId = "course_data_id"
                case currentHole = "current_hole"
                case thruHole = "thru_hole"
                case currentScore = "current_score"
            }
        }

        let payload = LiveRoundInsert(
            id: liveRoundId.uuidString.lowercased(),
            playerId: player.id.uuidString.lowercased(),
            courseName: courseDetail?.course.name ?? "",
            courseDataId: courseDetail?.course.id.uuidString.lowercased(),
            currentHole: 1,
            thruHole: 0,
            currentScore: 0
        )
        try await supabase.client.from("live_rounds").insert(payload).execute()
    }

    private func updateLiveRound(thruHole: Int, scoreVsPar: Int) async throws {
        guard let liveId = liveRoundId else { return }

        struct LiveRoundUpdate: Encodable {
            let currentHole: Int
            let thruHole: Int
            let currentScore: Int
            enum CodingKeys: String, CodingKey {
                case currentHole = "current_hole"
                case thruHole = "thru_hole"
                case currentScore = "current_score"
            }
        }

        let update = LiveRoundUpdate(currentHole: currentHole, thruHole: thruHole, currentScore: scoreVsPar)
        try await supabase.client
            .from("live_rounds")
            .update(update)
            .eq("id", value: liveId.uuidString.lowercased())
            .execute()
    }

    private func deleteLiveRound() async throws {
        guard let liveId = liveRoundId else { return }
        try await supabase.client
            .from("live_rounds")
            .delete()
            .eq("id", value: liveId.uuidString.lowercased())
            .execute()
        self.liveRoundId = nil
    }
}
