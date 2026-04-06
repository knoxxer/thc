// WatchConnectivityTests.swift
// THCTests/Service
//
// All 8 specs from §2.7.
// Tests compile but fail (red) until WatchSyncService is implemented (M11.2).

import XCTest
import WatchConnectivity
@testable import THC

final class WatchConnectivityTests: XCTestCase {

    var mockWCSession: MockWCSession!
    var watchSyncService: WatchSyncService!

    override func setUp() async throws {
        try await super.setUp()
        mockWCSession = MockWCSession()
        watchSyncService = WatchSyncService(wcSession: mockWCSession)
    }

    override func tearDown() async throws {
        watchSyncService = nil
        mockWCSession = nil
        try await super.tearDown()
    }

    // MARK: - §2.7.1 Course data transferred on round start

    func test_courseDataTransferredOnRoundStart() throws {
        // Given: course detail with 18 holes
        let courseDetail = CourseDetail.fixture(holeCount: 18)

        // When
        try watchSyncService.sendCourseToWatch(courseDetail)

        // Then: transferUserInfo called with all 18 holes' data
        XCTAssertEqual(mockWCSession.transferredUserInfoItems.count, 1,
                       "Exactly one transferUserInfo call expected for course data")
        let payload = mockWCSession.transferredUserInfoItems.first!
        XCTAssertNotNil(payload["course"], "Payload should contain course key")
        if let holes = payload["holes"] as? [[String: Any]] {
            XCTAssertEqual(holes.count, 18, "All 18 holes should be included")
        } else {
            XCTFail("Payload should contain 18 holes")
        }
    }

    // MARK: - §2.7.2 transferUserInfo used (not sendMessage) for course data

    func test_transferUserInfoUsed_notSendMessage() throws {
        // Given: connected watch
        let courseDetail = CourseDetail.fixture(holeCount: 18)

        // When
        try watchSyncService.sendCourseToWatch(courseDetail)

        // Then: transferUserInfo used, NOT sendMessage
        XCTAssertGreaterThan(mockWCSession.transferredUserInfoItems.count, 0,
                             "Course data must use transferUserInfo for guaranteed delivery")
        XCTAssertEqual(mockWCSession.sentMessages.count, 0,
                       "Course data must NOT use sendMessage")
    }

    // MARK: - §2.7.3 Watch receives course data when not in foreground

    func test_watchReceivesCourseData_whenBackgrounded() throws {
        // Given: phone sends course data via transferUserInfo
        let courseDetail = CourseDetail.fixture(holeCount: 18)
        try watchSyncService.sendCourseToWatch(courseDetail)

        // When: watch comes to foreground — simulate receiving the pending userInfo
        let pendingUserInfo = mockWCSession.transferredUserInfoItems.first!

        var receivedCourse: CourseDetail?
        watchSyncService.onCourseReceived = { detail in
            receivedCourse = detail
        }
        mockWCSession.simulateReceiveUserInfo(pendingUserInfo)

        // Then: course data is populated; delegate fires
        XCTAssertNotNil(receivedCourse,
                        "Watch should receive course data even when not in foreground at send time")
    }

    // MARK: - §2.7.4 Live update via sendMessage when watch is active

    func test_liveUpdateViaSendMessage_whenReachable() throws {
        // Given: watch is in foreground and reachable
        mockWCSession.isReachable = true
        let roundState = WatchRoundState(
            currentHole: 7,
            thruHole: 6,
            currentScore: -1
        )

        // When
        try watchSyncService.sendRoundStateToWatch(roundState)

        // Then: sendMessage used for low-latency delivery
        XCTAssertGreaterThan(mockWCSession.sentMessages.count, 0,
                             "Live update should use sendMessage when watch is reachable")
    }

    // MARK: - §2.7.5 Watch score syncs back to phone

    func test_watchScoreSyncsToPhone() {
        // Given: user enters score on watch; watch sends via transferUserInfo
        let scoreEntry = WatchScoreEntry(holeNumber: 7, strokes: 4, timestamp: Date())
        let userInfo: [String: Any] = [
            "type": "score",
            "holeNumber": scoreEntry.holeNumber,
            "strokes": scoreEntry.strokes,
            "timestamp": scoreEntry.timestamp.timeIntervalSince1970
        ]

        var receivedEntry: WatchScoreEntry?
        watchSyncService.onScoreReceived = { entry in
            receivedEntry = entry
        }

        // When: watch sends the score
        mockWCSession.simulateReceiveUserInfo(userInfo)

        // Then: phone receives the score; ScoreEntryViewModel reflects it
        XCTAssertNotNil(receivedEntry, "Phone should receive score entry from watch")
        XCTAssertEqual(receivedEntry?.holeNumber, 7)
        XCTAssertEqual(receivedEntry?.strokes, 4)
    }

    // MARK: - §2.7.6 Conflict resolution: last-write-wins

    func test_conflictResolution_lastWriteWins() {
        // Given: score entered for hole 7 on BOTH phone and watch before sync
        let phoneTimestamp = Date()
        let watchTimestamp = phoneTimestamp.addingTimeInterval(5)  // watch is 5 seconds later

        let phoneEntry = WatchScoreEntry(holeNumber: 7, strokes: 4, timestamp: phoneTimestamp)
        let watchEntry = WatchScoreEntry(holeNumber: 7, strokes: 5, timestamp: watchTimestamp)

        // When: sync completes
        let resolved = watchSyncService.resolveConflict(phone: phoneEntry, watch: watchEntry)

        // Then: last-write-wins (watch, which is more recent)
        XCTAssertEqual(resolved.strokes, 5,
                       "Last-write-wins: watch entry (more recent) should win")
        XCTAssertEqual(resolved.timestamp, watchTimestamp,
                       "Winning entry should preserve the watch timestamp")
    }

    // MARK: - §2.7.7 Watch standalone GPS activates when phone not reachable

    func test_standaloneGPSActivates_whenPhoneUnreachable() {
        // Given: phone is out of Bluetooth range
        mockWCSession.isReachable = false

        var standaloneActivated = false
        watchSyncService.onStandaloneGPSRequired = {
            standaloneActivated = true
        }

        // When: service detects phone not reachable
        watchSyncService.checkConnectivity()

        // Then: IndependentGPSService activation signal fires
        XCTAssertTrue(standaloneActivated,
                      "Standalone GPS should activate when phone is not reachable")
    }

    // MARK: - §2.7.8 Course data delivered despite watch app not running at send time

    func test_courseDataDelivered_despiteWatchAppNotRunning() throws {
        // Given: course data sent via transferUserInfo while watch app is not running
        let courseDetail = CourseDetail.fixture(holeCount: 18)
        try watchSyncService.sendCourseToWatch(courseDetail)

        // The pending item sits in WCSession queue
        let pendingItem = mockWCSession.transferredUserInfoItems.first!

        // When: user opens watch app later — session receives the queued item
        var courseWasDelivered = false
        watchSyncService.onCourseReceived = { _ in
            courseWasDelivered = true
        }
        mockWCSession.simulateReceiveUserInfo(pendingItem)

        // Then: pending transferUserInfo items are processed; course data available
        XCTAssertTrue(courseWasDelivered,
                      "Course data should be delivered even if watch app was not running at send time")
    }
}

// MARK: - Fixtures

private extension CourseDetail {
    static func fixture(holeCount: Int) -> CourseDetail {
        let courseId = UUID()
        let holes = (1...holeCount).map { i in
            CourseHole(
                id: UUID(),
                courseId: courseId,
                holeNumber: i,
                par: [3, 4, 5][i % 3],
                yardage: 300 + i * 20,
                handicap: i,
                greenLat: 32.8900 + Double(i) * 0.001,
                greenLon: -117.2500 - Double(i) * 0.001,
                greenPolygon: nil,
                teeLat: 32.8910 + Double(i) * 0.001,
                teeLon: -117.2510 - Double(i) * 0.001,
                source: "tap_and_save",
                savedBy: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        return CourseDetail(
            course: CourseData(
                id: courseId,
                golfcourseapiId: nil,
                name: "Test Course",
                clubName: nil,
                address: nil,
                lat: 32.8990,
                lon: -117.2519,
                holeCount: holeCount,
                par: 72,
                osmId: nil,
                hasGreenData: false,
                createdAt: Date(),
                updatedAt: Date()
            ),
            holes: holes,
            dataSource: .tapAndSave
        )
    }
}
