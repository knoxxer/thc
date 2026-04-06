import Foundation
import WatchConnectivity
import Combine
import Shared

/// WatchConnectivity delegate for the watchOS side.
///
/// Receives course/round data from the phone via `transferUserInfo` (guaranteed delivery)
/// and publishes it as `@Published` properties for use by SwiftUI views.
/// Sends score entries back to the phone via `transferUserInfo` when reachable,
/// falling back to `transferUserInfo` when not.
final class PhoneConnectivityService: NSObject, ObservableObject, PhoneConnectivityServiceProviding, @unchecked Sendable {

    // MARK: - Published State

    /// The latest round state received from the phone.
    @Published private(set) var currentRoundState: WatchRoundState?

    /// Top standings pushed from the phone via updateApplicationContext.
    @Published private(set) var standings: [SeasonStanding] = []

    /// True while an active WCSession is reachable.
    @Published private(set) var isPhoneReachable: Bool = false

    // MARK: - AsyncStream Sources

    private var courseDataContinuation: AsyncStream<WatchRoundState>.Continuation?
    private var scoreEntriesContinuation: AsyncStream<WatchScoreEntry>.Continuation?

    /// AsyncStream of round state updates. Suitable for non-SwiftUI consumers.
    let courseData: AsyncStream<WatchRoundState>

    // MARK: - Init

    override init() {
        var courseDataCont: AsyncStream<WatchRoundState>.Continuation!
        courseData = AsyncStream<WatchRoundState> { continuation in
            courseDataCont = continuation
        }
        courseDataContinuation = courseDataCont

        super.init()
        activateSession()
    }

    deinit {
        courseDataContinuation?.finish()
        scoreEntriesContinuation?.finish()
    }

    // MARK: - WCSession Activation

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - PhoneConnectivityServiceProviding

    /// Send a hole score to the phone.
    /// Uses `sendMessage` when reachable for low latency; falls back to `transferUserInfo`.
    func sendScore(_ entry: WatchScoreEntry) throws {
        let session = WCSession.default
        guard session.activationState == .activated else {
            throw ConnectivityError.sessionNotActivated
        }

        let data = try JSONEncoder().encode(entry)
        let payload: [String: Any] = [
            MessageKey.scoreEntry: data
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                // On failure, fall back to guaranteed delivery
                self?.transferScoreAsFallback(entry: entry)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Private Helpers

    private func transferScoreAsFallback(entry: WatchScoreEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        let payload: [String: Any] = [MessageKey.scoreEntry: data]
        WCSession.default.transferUserInfo(payload)
    }

    private func handleReceivedUserInfo(_ userInfo: [String: Any]) {
        if let data = userInfo[MessageKey.roundState] as? Data,
           let state = try? JSONDecoder().decode(WatchRoundState.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                self?.currentRoundState = state
            }
            courseDataContinuation?.yield(state)
        }

        if let data = userInfo[MessageKey.standings] as? Data,
           let standings = try? JSONDecoder().decode([SeasonStanding].self, from: data) {
            DispatchQueue.main.async { [weak self] in
                self?.standings = standings
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = reachable
        }

        // Apply any pending application context that arrived before activation.
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            handleReceivedUserInfo(context)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = isReachable
        }
        // Notify IndependentGPSService so it can activate/deactivate standalone GPS.
        NotificationCenter.default.post(
            name: .watchPhoneReachabilityChanged,
            object: nil,
            userInfo: ["isReachable": isReachable]
        )
    }

    /// Handles `transferUserInfo` payloads — guaranteed delivery channel.
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        handleReceivedUserInfo(userInfo)
    }

    /// Handles `updateApplicationContext` — standings use latest-value-wins semantics.
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleReceivedUserInfo(applicationContext)
    }

    /// Handles `sendMessage` payloads — used for live reachable updates.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        handleReceivedUserInfo(message)
    }
}

// MARK: - Errors

enum ConnectivityError: LocalizedError {
    case sessionNotActivated
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .sessionNotActivated:
            return "Watch session is not activated. Please open the app on your iPhone."
        case .encodingFailed:
            return "Failed to encode score data."
        }
    }
}

// MARK: - Message Keys

private enum MessageKey {
    static let roundState = "roundState"
    static let scoreEntry = "scoreEntry"
    static let standings = "standings"
}
