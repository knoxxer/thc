// BackgroundRefreshTests.swift
// THCTests/Service
//
// 2 tests from M14.1.
// Tests compile but fail (red) until BackgroundRefreshService is implemented (M14.2).

import XCTest
import BackgroundTasks
import SwiftData
import Shared
@testable import THC

final class BackgroundRefreshTests: XCTestCase {

    var mockScheduler: MockBGTaskScheduler!
    var mockSupabase: MockSupabaseClient!
    var mockStorage: MockOfflineStorage!
    var syncService: SyncService!
    var mockCourseDataService: MockCourseDataServiceSimple!
    var backgroundRefreshService: BackgroundRefreshService!

    override func setUp() async throws {
        try await super.setUp()
        mockScheduler = MockBGTaskScheduler()
        mockSupabase = MockSupabaseClient()
        mockStorage = MockOfflineStorage()
        syncService = SyncService(supabase: mockSupabase, storage: mockStorage)
        mockCourseDataService = MockCourseDataServiceSimple()
        backgroundRefreshService = BackgroundRefreshService(
            scheduler: mockScheduler,
            syncService: syncService,
            courseDataService: mockCourseDataService
        )
    }

    override func tearDown() async throws {
        backgroundRefreshService = nil
        mockCourseDataService = nil
        syncService = nil
        mockStorage = nil
        mockSupabase = nil
        mockScheduler = nil
        try await super.tearDown()
    }

    // MARK: - M14.1 — Background refresh registered in BGTaskScheduler

    func test_backgroundRefreshRegistered_inBGTaskScheduler() {
        // Given / When: service registers its task
        backgroundRefreshService.registerTasks()

        // Then: the task identifier is registered
        XCTAssertTrue(
            mockScheduler.registeredIdentifiers.contains("com.thc.app.refresh"),
            "Background refresh task should be registered with BGTaskScheduler"
        )
    }

    // MARK: - M14.1 — Background refresh schedules next refresh

    func test_backgroundRefresh_schedulesNextRefresh() {
        // When: schedule is called
        backgroundRefreshService.scheduleAppRefresh()

        // Then: a task request was submitted to the scheduler
        XCTAssertFalse(mockScheduler.submittedRequests.isEmpty,
                       "scheduleAppRefresh should submit a task request")
    }
}

// MARK: - MockBGTaskScheduler

final class MockBGTaskScheduler: BGTaskSchedulerProviding, @unchecked Sendable {

    var registeredIdentifiers: [String] = []
    var submittedRequests: [BGTaskRequest] = []
    var launchHandlers: [String: (BGTask) -> Void] = [:]

    @discardableResult
    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BGTask) -> Void
    ) -> Bool {
        registeredIdentifiers.append(identifier)
        launchHandlers[identifier] = launchHandler
        return true
    }

    func submit(_ taskRequest: BGTaskRequest) throws {
        submittedRequests.append(taskRequest)
    }
}

// MARK: - Simple CourseDataService mock for BackgroundRefreshTests

final class MockCourseDataServiceSimple: CourseDataServiceProviding, @unchecked Sendable {
    func searchCourses(query: String) async throws -> [CourseSearchResult] { [] }
    func getCourseDetail(courseId: UUID) async throws -> CourseDetail? { nil }
    func nearbyCourses(lat: Double, lon: Double, radiusKm: Double) async throws -> [CourseData] { [] }
    func saveGreenPin(courseId: UUID, holeNumber: Int, greenLat: Double, greenLon: Double, savedBy: UUID) async throws {}
    func prefetchNearbyCourses(lat: Double, lon: Double, radiusKm: Double) async {}
    func getOrCreateCourse(from result: CourseSearchResult) async throws -> UUID { UUID() }
}
