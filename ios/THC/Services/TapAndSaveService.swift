import Foundation
import CoreLocation
import SwiftData
import Shared

/// Coordinates tap-and-save green pin saves and fetches.
/// Wraps CourseDataService for green pin operations and provides
/// distance calculation utilities.
final class TapAndSaveService: @unchecked Sendable {
    private let supabase: SupabaseClientProviding
    private let context: ModelContext

    init(supabase: SupabaseClientProviding, modelContainer: ModelContainer) {
        self.supabase = supabase
        self.context = ModelContext(modelContainer)
    }

    convenience init(supabase: SupabaseClientProviding, modelContainer: ModelContainer, networkAvailable: Bool) {
        self.init(supabase: supabase, modelContainer: modelContainer)
        // networkAvailable is used for offline behavior; stub for now
    }

    // MARK: - Save

    func saveGreenPin(
        courseId: UUID,
        holeNumber: Int,
        greenLat: Double,
        greenLon: Double,
        savedBy: UUID
    ) async throws {
        let payload = TapAndSaveGreenPinPayload(
            courseId: courseId.uuidString.lowercased(),
            holeNumber: holeNumber,
            greenLat: greenLat,
            greenLon: greenLon,
            source: "tap_and_save",
            savedBy: savedBy.uuidString.lowercased()
        )
        try await supabase.client
            .from("course_holes")
            .upsert(payload, onConflict: "course_id,hole_number")
            .execute()

        // Check if all 18 holes now have pins
        try await updateHasGreenDataIfComplete(courseId: courseId)
    }

    // MARK: - Fetch

    func fetchCourseHoles(courseID: UUID) async throws -> [CourseHole] {
        let courseIdString = courseID.uuidString.lowercased()
        return try await supabase.client
            .from("course_holes")
            .select()
            .eq("course_id", value: courseIdString)
            .order("hole_number")
            .execute()
            .value
    }

    // MARK: - Cache

    func getCachedHoles(courseID: UUID) throws -> [CachedHole] {
        let descriptor = FetchDescriptor<CachedCourse>(
            predicate: #Predicate { $0.id == courseID }
        )
        guard let cached = try context.fetch(descriptor).first else { return [] }
        return cached.holes
    }

    func getPendingPins() throws -> [CachedHole] {
        // Return all cached holes that haven't been synced yet
        // For now return empty — full offline queue implementation is pending
        return []
    }

    // MARK: - Distance

    func instantDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        DistanceCalculator.distanceInYards(from: from, to: to)
    }

    // MARK: - Private

    // MARK: - Private Helpers

    private func updateHasGreenDataIfComplete(courseId: UUID) async throws {
        let courseIdString = courseId.uuidString.lowercased()
        let holes: [CourseHole] = try await supabase.client
            .from("course_holes")
            .select()
            .eq("course_id", value: courseIdString)
            .execute()
            .value

        let courses: [CourseData] = try await supabase.client
            .from("course_data")
            .select("hole_count")
            .eq("id", value: courseIdString)
            .limit(1)
            .execute()
            .value

        guard let course = courses.first else { return }
        let holesWithPins = holes.filter { $0.greenLat != nil }.count
        if holesWithPins >= course.holeCount {
            let updatePayload = HasGreenDataPayload(hasGreenData: true)
            try await supabase.client
                .from("course_data")
                .update(updatePayload)
                .eq("id", value: courseIdString)
                .execute()
        }
    }
}

// MARK: - Payloads

private struct TapAndSaveGreenPinPayload: Encodable {
    let courseId: String
    let holeNumber: Int
    let greenLat: Double
    let greenLon: Double
    let source: String
    let savedBy: String

    private enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case holeNumber = "hole_number"
        case greenLat = "green_lat"
        case greenLon = "green_lon"
        case source
        case savedBy = "saved_by"
    }
}

private struct HasGreenDataPayload: Encodable {
    let hasGreenData: Bool

    private enum CodingKeys: String, CodingKey {
        case hasGreenData = "has_green_data"
    }
}
