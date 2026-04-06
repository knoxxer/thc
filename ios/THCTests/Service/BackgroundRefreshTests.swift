// BackgroundRefreshTests.swift
// THCTests/Service
//
// 2 tests from M14.1.
// Tests compile but fail (red) until BackgroundRefreshService is implemented (M14.2).

import XCTest
import BackgroundTasks
@testable import THC

final class BackgroundRefreshTests: XCTestCase {

    var mockScheduler: MockBGTaskScheduler!
    var mockSupabase: MockSupabaseClient!
    var backgroundRefreshService: BackgroundRefreshService!

    override func setUp() async throws {
        try await super.setUp()
        mockScheduler = MockBGTaskScheduler()
        mockSupabase = MockSupabaseClient()
        backgroundRefreshService = BackgroundRefreshService(
            scheduler: mockScheduler,
            supabase: mockSupabase
        )
    }

    override func tearDown() async throws {
        backgroundRefreshService = nil
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
            mockScheduler.registeredIdentifiers.contains("com.thc.app.standings-refresh") ||
            mockScheduler.registeredIdentifiers.contains("com.thc.app.background-refresh"),
            "Background refresh task should be registered with BGTaskScheduler"
        )
    }

    // MARK: - M14.1 — Background refresh fetches standings and course data

    func test_backgroundRefresh_fetchesStandingsAndCourseData() async throws {
        // Given: service configured
        let standingsBefore = mockSupabase.insertCalls.count

        // When: trigger the background refresh handler
        await backgroundRefreshService.performBackgroundRefresh()

        // Then: standings + course data fetches were made
        let standingsFetchCalls = mockSupabase.capturedSelectCalls.filter {
            $0 == "season_standings" || $0 == "rounds"
        }
        XCTAssertFalse(standingsFetchCalls.isEmpty,
                       "Background refresh should fetch standings data")
    }
}

// MARK: - MockBGTaskScheduler

protocol BGTaskSchedulerProviding {
    func register(forTaskWithIdentifier identifier: String,
                  using queue: DispatchQueue?,
                  launchHandler: @escaping (Any) -> Void)
    func submit(_ taskRequest: Any) throws
}

final class MockBGTaskScheduler: BGTaskSchedulerProviding {

    var registeredIdentifiers: [String] = []
    var submittedRequests: [Any] = []
    var launchHandlers: [String: (Any) -> Void] = [:]

    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (Any) -> Void
    ) {
        registeredIdentifiers.append(identifier)
        launchHandlers[identifier] = launchHandler
    }

    func submit(_ taskRequest: Any) throws {
        submittedRequests.append(taskRequest)
    }

    /// Simulate the system launching a background task.
    func triggerTask(identifier: String, with task: Any) {
        launchHandlers[identifier]?(task)
    }
}

// MARK: - MockSupabaseClient extension for select tracking

extension MockSupabaseClient {
    var capturedSelectCalls: [String] {
        // In real implementation, track which table selects were made
        // For now return empty — implementation will populate this
        return []
    }
}
