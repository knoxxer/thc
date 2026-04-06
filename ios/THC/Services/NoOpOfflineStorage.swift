import Foundation
import Shared

/// No-op implementation of `OfflineStorageProviding`.
///
/// Used in contexts where a `ModelContext` is unavailable (e.g., previews,
/// placeholder views that haven't yet received the model container).
/// All writes are silently dropped; all reads return empty results.
final class NoOpOfflineStorage: OfflineStorageProviding, @unchecked Sendable {
    func saveRound(_ round: LocalRound) throws {}
    func unsyncedRounds() throws -> [LocalRound] { [] }
    func markRoundSynced(_ id: UUID) throws {}
    func cacheCourse(_ course: CourseData, holes: [CourseHole]) throws {}
    func getCachedCourse(id: UUID) -> CachedCourse? { nil }
    func getNearbyCachedCourses(lat: Double, lon: Double, radiusKm: Double) -> [CachedCourse] { [] }
    func finalizeRound(id: UUID, grossScore: Int, courseHandicap: Int, points: Int) throws {}
    func saveHoleScore(_ score: LocalHoleScore, roundId: UUID) throws {}
}
