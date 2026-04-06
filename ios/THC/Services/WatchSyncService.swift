import Foundation
import WatchConnectivity
import Shared

// MARK: - Protocol

/// iPhone-side WatchConnectivity bridge.
/// The watch target has a symmetric `PhoneConnectivityService`.
protocol WatchSyncServiceProviding: Sendable {
    /// Send full course data to the watch via `transferUserInfo` (queued, guaranteed delivery).
    func sendCourseToWatch(_ course: CourseDetail) throws

    /// Send live round state to the watch.
    /// Uses `sendMessage` when the watch is reachable; falls back to `transferUserInfo`.
    func sendRoundStateToWatch(_ state: WatchRoundState) throws

    /// Incoming score entries from the watch, delivered as an `AsyncStream`.
    var watchScoreEntries: AsyncStream<WatchScoreEntry> { get }
}

// MARK: - WCSession Abstraction (for testability)

/// Protocol abstracting WCSession so tests can inject a mock.
protocol WCSessionProtocol: AnyObject {
    var isReachable: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    var delegate: WCSessionDelegate? { get set }

    func activate()
    @discardableResult
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer
    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )
    func updateApplicationContext(_ applicationContext: [String: Any]) throws
}

extension WCSession: WCSessionProtocol {}

// MARK: - WCSession Key Constants

private enum WatchKey {
    static let courseData = "courseData"
    static let roundState = "roundState"
    static let scoreEntry = "scoreEntry"
}

// MARK: - Implementation

@Observable
final class WatchSyncService: NSObject, WatchSyncServiceProviding, WCSessionDelegate, @unchecked Sendable {

    // MARK: - Public

    /// Incoming score entries from the watch.
    let watchScoreEntries: AsyncStream<WatchScoreEntry>

    // MARK: - Private

    private let session: WCSessionProtocol
    private var continuation: AsyncStream<WatchScoreEntry>.Continuation?

    // MARK: - Init

    init(session: WCSessionProtocol = WCSession.default) {
        self.session = session

        var capturedContinuation: AsyncStream<WatchScoreEntry>.Continuation?
        watchScoreEntries = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation

        super.init()

        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    deinit {
        continuation?.finish()
    }

    // MARK: - WatchSyncServiceProviding

    func sendCourseToWatch(_ course: CourseDetail) throws {
        guard WCSession.isSupported(), session.isPaired, session.isWatchAppInstalled else { return }

        let firstHole = course.holes.first
        let polygonData: Data?
        if let polygon = firstHole?.greenPolygon {
            polygonData = try? JSONEncoder().encode(polygon)
        } else {
            polygonData = nil
        }

        let state = WatchRoundState(
            courseName: course.course.name,
            currentHole: 1,
            par: course.course.par,
            greenLat: firstHole?.greenLat,
            greenLon: firstHole?.greenLon,
            greenPolygonJSON: polygonData,
            nextHazardName: nil,
            nextHazardCarry: nil,
            holeScores: [:]
        )

        let data = try JSONEncoder().encode(state)
        // transferUserInfo is queued and guaranteed — survives app termination.
        session.transferUserInfo([WatchKey.courseData: data])
    }

    func sendRoundStateToWatch(_ state: WatchRoundState) throws {
        guard WCSession.isSupported(), session.isPaired, session.isWatchAppInstalled else { return }

        let data = try JSONEncoder().encode(state)

        if session.isReachable {
            // sendMessage delivers immediately when both apps are in the foreground.
            session.sendMessage([WatchKey.roundState: data], replyHandler: nil) { [weak self] error in
                guard let self else { return }
                print("[WatchSyncService] sendMessage failed, falling back to transferUserInfo: \(error)")
                self.session.transferUserInfo([WatchKey.roundState: data])
            }
        } else {
            // Fall back to transferUserInfo when the watch is not immediately reachable.
            session.transferUserInfo([WatchKey.roundState: data])
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchSyncService] WCSession activation failed: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Required on iPhone — reactivate after a watch swap.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingMessage(message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Incoming Message Processing

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let data = message[WatchKey.scoreEntry] as? Data,
              let entry = try? JSONDecoder().decode(WatchScoreEntry.self, from: data)
        else { return }
        continuation?.yield(entry)
    }
}
