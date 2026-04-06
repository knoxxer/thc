// MockWCSession.swift
// THCTests/Mocks
//
// WCSessionProtocol conformer that captures all WatchConnectivity calls
// without requiring physical devices.
//
// Key assertion: course data MUST use transferredUserInfoItems (guaranteed
// delivery), while live hole updates use sentMessages (low-latency, requires
// watch to be reachable).

import Foundation
import WatchConnectivity
@testable import THC

// WCSessionProtocol is defined in THC/Services/WatchSyncService.swift
// MockWCSession conforms to it for test injection.

// MARK: - Mock

final class MockWCSession: WCSessionProtocol {

    // MARK: - Configurable state

    var isReachable: Bool = true
    var isPaired: Bool = true
    var isWatchAppInstalled: Bool = true

    // MARK: - Captured calls (assert on these in tests)

    /// Payloads sent via transferUserInfo (guaranteed delivery).
    var transferredUserInfoItems: [[String: Any]] = []

    /// Payloads sent via sendMessage (requires watch to be in foreground).
    var sentMessages: [[String: Any]] = []

    /// Track whether activate() was called.
    var activateCallCount: Int = 0

    /// Reply handlers captured for sendMessage calls (tests can invoke them).
    var capturedReplyHandlers: [([String: Any]) -> Void] = []

    // MARK: - WCSessionProtocol

    weak var delegate: WCSessionDelegate?

    func activate() {
        activateCallCount += 1
    }

    @discardableResult
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer {
        transferredUserInfoItems.append(userInfo)
        // WCSessionUserInfoTransfer can't be constructed directly.
        // The return value is @discardableResult and never inspected in tests.
        // Use NSObject + unsafeBitCast as a workaround for the final class.
        return unsafeBitCast(NSObject(), to: WCSessionUserInfoTransfer.self)
    }

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        if isReachable {
            sentMessages.append(message)
            if let reply = replyHandler {
                capturedReplyHandlers.append(reply)
            }
        } else {
            errorHandler?(WatchConnectivityError.notReachable)
        }
    }

    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
        // No-op in mock — standings push is tested via transferUserInfo
    }

    // MARK: - Simulation helpers

    /// Simulate the watch sending user info back to the phone.
    func simulateReceiveUserInfo(_ userInfo: [String: Any]) {
        delegate?.session?(WCSession.default, didReceiveUserInfo: userInfo)
    }

    /// Simulate the watch sending a message to the phone.
    func simulateReceiveMessage(_ message: [String: Any]) {
        delegate?.session?(
            WCSession.default,
            didReceiveMessage: message,
            replyHandler: { _ in }
        )
    }

    func reset() {
        transferredUserInfoItems.removeAll()
        sentMessages.removeAll()
        capturedReplyHandlers.removeAll()
        activateCallCount = 0
    }
}

// MARK: - Watch Connectivity Error

enum WatchConnectivityError: Error, LocalizedError {
    case notReachable
    case watchAppNotInstalled
    case notPaired

    var errorDescription: String? {
        switch self {
        case .notReachable: return "Watch is not reachable"
        case .watchAppNotInstalled: return "Watch app is not installed"
        case .notPaired: return "Watch is not paired"
        }
    }
}
