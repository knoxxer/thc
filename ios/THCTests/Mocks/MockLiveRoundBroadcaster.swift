// MockLiveRoundBroadcaster.swift
// THCTests/Mocks
//
// No-op implementation of LiveRoundBroadcasting for unit tests.

import Foundation
@testable import THC

final class MockLiveRoundBroadcaster: LiveRoundBroadcasting, @unchecked Sendable {

    // MARK: - Captured calls

    struct StartCall {
        let id: UUID
        let playerId: UUID
        let courseName: String
        let courseDataId: UUID?
        let currentHole: Int
        let thruHole: Int
        let currentScore: Int
    }

    struct UpdateCall {
        let id: UUID
        let currentHole: Int
        let thruHole: Int
        let currentScore: Int
    }

    var startCalls: [StartCall] = []
    var updateCalls: [UpdateCall] = []
    var deleteCalls: [UUID] = []

    // MARK: - LiveRoundBroadcasting

    func startLiveRound(
        id: UUID, playerId: UUID, courseName: String,
        courseDataId: UUID?, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws {
        startCalls.append(StartCall(
            id: id, playerId: playerId, courseName: courseName,
            courseDataId: courseDataId, currentHole: currentHole,
            thruHole: thruHole, currentScore: currentScore
        ))
    }

    func updateLiveRound(
        id: UUID, currentHole: Int, thruHole: Int, currentScore: Int
    ) async throws {
        updateCalls.append(UpdateCall(
            id: id, currentHole: currentHole,
            thruHole: thruHole, currentScore: currentScore
        ))
    }

    func deleteLiveRound(id: UUID) async throws {
        deleteCalls.append(id)
    }
}
