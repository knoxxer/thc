import Foundation
import CoreLocation
import Observation
import Shared

/// Drives course search, auto-detection, and tap-and-save coordination.
@Observable
final class CourseSetupViewModel: @unchecked Sendable {
    private(set) var searchResults: [CourseSearchResult] = []
    private(set) var nearbyCourses: [CourseData] = []
    private(set) var detectedCourse: CourseData?
    private(set) var selectedCourse: CourseDetail?
    private(set) var isSearching: Bool = false
    private(set) var isLoadingNearby: Bool = false
    private(set) var multipleCourseNearby: [CourseData] = []  // resort scenario
    private(set) var error: String?

    // Favorites stored in SwiftData (keys are course UUIDs as strings)
    private(set) var favoriteCourseIds: Set<String> = []

    private let courseDataService: CourseDataServiceProviding
    private let locationManager: LocationManager
    private var searchTask: Task<Void, Never>?

    init(
        courseDataService: CourseDataServiceProviding,
        locationManager: LocationManager
    ) {
        self.courseDataService = courseDataService
        self.locationManager = locationManager
    }

    // MARK: - Search

    /// Searches courses by name via GolfCourseAPI.
    /// Debounces: cancels the previous search if called rapidly.
    func search(query: String) async {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        error = nil

        searchTask = Task {
            do {
                // 300ms debounce
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let results = try await courseDataService.searchCourses(query: trimmed)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch is CancellationError {
                // No-op
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    /// Selects a course from search results and loads its full detail.
    @discardableResult
    func selectCourse(_ result: CourseSearchResult) async throws -> CourseDetail {
        // Build a CourseData placeholder with the API result's ID
        // The service will upsert it if needed.
        let courseId = UUID()   // service will deduplicate by golfcourseapi_id
        guard let detail = try await courseDataService.getCourseDetail(courseId: courseId) else {
            throw CourseSetupError.courseNotFound
        }
        selectedCourse = detail
        return detail
    }

    // MARK: - Auto-Detection

    /// Detects nearby courses within 2km, auto-selects if exactly one within 500m.
    func detectNearbyCourse() async {
        guard let coord = locationManager.coordinate else { return }
        isLoadingNearby = true
        error = nil

        do {
            let nearby = try await courseDataService.nearbyCourses(
                lat: coord.latitude,
                lon: coord.longitude,
                radiusKm: 2.0
            )
            nearbyCourses = nearby

            // Determine courses strictly within 500m
            let within500m = nearby.filter { course in
                let courseLoc = CLLocation(latitude: course.lat, longitude: course.lon)
                let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                return courseLoc.distance(from: userLoc) <= 500
            }

            if within500m.count == 1 {
                detectedCourse = within500m.first
                multipleCourseNearby = []
            } else if within500m.count > 1 {
                // Resort scenario — show picker
                detectedCourse = nil
                multipleCourseNearby = within500m
            } else {
                detectedCourse = nil
                multipleCourseNearby = []
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingNearby = false
    }

    // MARK: - Tap-and-Save

    func saveGreenPin(holeNumber: Int, lat: Double, lon: Double, savedBy: UUID) async throws {
        guard let course = selectedCourse?.course else {
            throw CourseSetupError.noCourseSelected
        }
        try await courseDataService.saveGreenPin(
            courseId: course.id,
            holeNumber: holeNumber,
            greenLat: lat,
            greenLon: lon,
            savedBy: savedBy
        )
    }

    // MARK: - Direct Detail Load

    /// Load course detail by ID (used by list rows that already have the course ID).
    func loadCourseDetail(courseId: UUID) async throws -> CourseDetail? {
        return try await courseDataService.getCourseDetail(courseId: courseId)
    }

    // MARK: - Favorites

    func toggleFavorite(courseId: UUID) {
        let key = courseId.uuidString
        if favoriteCourseIds.contains(key) {
            favoriteCourseIds.remove(key)
        } else {
            favoriteCourseIds.insert(key)
        }
        // Persist to UserDefaults (simple list for a 10-user app)
        UserDefaults.standard.set(Array(favoriteCourseIds), forKey: "favoriteCourseIds")
    }

    func isFavorite(courseId: UUID) -> Bool {
        favoriteCourseIds.contains(courseId.uuidString)
    }

    func loadFavorites() {
        let saved = UserDefaults.standard.stringArray(forKey: "favoriteCourseIds") ?? []
        favoriteCourseIds = Set(saved)
    }
}

// MARK: - Errors

enum CourseSetupError: LocalizedError {
    case courseNotFound
    case noCourseSelected

    var errorDescription: String? {
        switch self {
        case .courseNotFound: return "Course details could not be loaded."
        case .noCourseSelected: return "No course is selected."
        }
    }
}
