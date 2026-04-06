// TestModelContainer.swift
// THCTests/Mocks
//
// Factory for in-memory SwiftData ModelContainers used in tests.
// Each test should call TestModelContainer.create() in setUp() to get
// a fresh, isolated container — no cross-test state leakage.
//
// Usage:
//   let container = try TestModelContainer.create()
//   let context = ModelContext(container)
//   let storage = OfflineStorage(modelContext: context)

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
            let round = LocalRound()
            round.id = UUID()
            round.playerId = UUID()
            round.seasonId = UUID()
            round.playedAt = "2026-0\(i + 1)-15"
            round.courseName = "Test Course \(i)"
            round.par = 72
            round.grossScore = 90 + i
            round.courseHandicap = 18
            round.points = 10
            round.source = "app"
            round.syncedToSupabase = false
            round.createdAt = Date()
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
            let round = LocalRound()
            round.id = UUID()
            round.playerId = UUID()
            round.seasonId = UUID()
            round.playedAt = "2026-01-15"
            round.courseName = "Test Course"
            round.par = 72
            round.grossScore = 90
            round.courseHandicap = 18
            round.points = 10
            round.source = "app"
            round.syncedToSupabase = false
            round.createdAt = Date()
            context.insert(round)
        }

        // 1 synced
        let synced = LocalRound()
        synced.id = UUID()
        synced.playerId = UUID()
        synced.seasonId = UUID()
        synced.playedAt = "2026-01-10"
        synced.courseName = "Other Course"
        synced.par = 72
        synced.grossScore = 85
        synced.courseHandicap = 15
        synced.points = 12
        synced.source = "app"
        synced.syncedToSupabase = true
        synced.createdAt = Date()
        context.insert(synced)

        try context.save()
        return container
    }
}
