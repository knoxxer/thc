// TestModelContainer.swift
// THCTests/Mocks
//
// Factory for in-memory SwiftData ModelContainers used in tests.
// Each test should call TestModelContainer.create() in setUp() to get
// a fresh, isolated container -- no cross-test state leakage.
//
// Usage:
//   let container = try TestModelContainer.create()
//   let context = ModelContext(container)
//   let storage = OfflineStorage(context: context)

import Foundation
import SwiftData
@testable import THC

enum TestModelContainer {

    /// Creates a fresh in-memory ModelContainer for test isolation.
    /// Includes all @Model types required by the THC app.
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LocalRound.self,
                 LocalHoleScore.self,
                 CachedCourse.self,
                 CachedHole.self,
            configurations: config
        )
    }

    /// Creates a container pre-populated with sample data for convenience.
    static func createWithSampleRounds(count: Int = 3) throws -> ModelContainer {
        let container = try create()
        let context = ModelContext(container)

        for i in 0..<count {
            let round = LocalRound(
                id: UUID(),
                playerId: UUID(),
                seasonId: UUID(),
                playedAt: "2026-0\(i + 1)-15",
                courseName: "Test Course \(i)",
                par: 72,
                grossScore: 90 + i,
                courseHandicap: 18,
                points: 10,
                source: "app",
                syncedToSupabase: false,
                holeScores: [],
                createdAt: Date()
            )
            context.insert(round)
        }

        try context.save()
        return container
    }

    /// Creates a container with a mix of synced and unsynced rounds.
    static func createWithMixedSyncStatus() throws -> ModelContainer {
        let container = try create()
        let context = ModelContext(container)

        // 2 unsynced
        for _ in 0..<2 {
            let round = LocalRound(
                id: UUID(),
                playerId: UUID(),
                seasonId: UUID(),
                playedAt: "2026-01-15",
                courseName: "Test Course",
                par: 72,
                grossScore: 90,
                courseHandicap: 18,
                points: 10,
                source: "app",
                syncedToSupabase: false,
                holeScores: [],
                createdAt: Date()
            )
            context.insert(round)
        }

        // 1 synced
        let synced = LocalRound(
            id: UUID(),
            playerId: UUID(),
            seasonId: UUID(),
            playedAt: "2026-01-10",
            courseName: "Other Course",
            par: 72,
            grossScore: 85,
            courseHandicap: 15,
            points: 12,
            source: "app",
            syncedToSupabase: true,
            holeScores: [],
            createdAt: Date()
        )
        context.insert(synced)

        try context.save()
        return container
    }
}
