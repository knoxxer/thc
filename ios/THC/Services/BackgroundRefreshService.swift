import Foundation
import BackgroundTasks

// MARK: - Protocol

/// Injectable abstraction over BGTaskScheduler for testability.
protocol BGTaskSchedulerProviding: Sendable {
    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BGTask) -> Void
    ) -> Bool

    func submit(_ taskRequest: BGTaskRequest) throws
}

extension BGTaskScheduler: BGTaskSchedulerProviding {}

// MARK: - Task Identifiers

/// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
enum BackgroundTaskIdentifier {
    static let appRefresh = "com.thc.app.refresh"
}

// MARK: - Protocol

protocol BackgroundRefreshServiceProviding: Sendable {
    /// Register background task handlers. Call from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    func registerTasks()

    /// Schedule the next background refresh. Call after each successful refresh
    /// and on app foreground.
    func scheduleAppRefresh()
}

// MARK: - Implementation

/// Schedules and handles `BGAppRefreshTask` to keep standings and the offline round
/// queue up to date while the app is not in the foreground.
///
/// Each refresh: (1) syncs pending local rounds to Supabase, (2) refreshes the active
/// season standings, (3) prefetches nearby course data using the last known GPS location.
final class BackgroundRefreshService: BackgroundRefreshServiceProviding, @unchecked Sendable {
    private let scheduler: BGTaskSchedulerProviding
    private let syncService: SyncServiceProviding
    private let courseDataService: CourseDataServiceProviding

    /// Minimum fetch interval — system may throttle more aggressively based on
    /// usage patterns, battery, and connectivity.
    private let minimumFetchInterval: TimeInterval = 15 * 60  // 15 minutes

    init(
        scheduler: BGTaskSchedulerProviding = BGTaskScheduler.shared,
        syncService: SyncServiceProviding,
        courseDataService: CourseDataServiceProviding
    ) {
        self.scheduler = scheduler
        self.syncService = syncService
        self.courseDataService = courseDataService
    }

    // MARK: - BackgroundRefreshServiceProviding

    func registerTasks() {
        scheduler.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.appRefresh,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskIdentifier.appRefresh
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumFetchInterval)

        do {
            try scheduler.submit(request)
        } catch {
            // Scheduling can fail in the simulator or when the identifier is
            // missing from Info.plist. Log and continue — it's non-fatal.
            print("[BackgroundRefreshService] Failed to schedule refresh: \(error)")
        }
    }

    // MARK: - Task Handler

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately so the chain continues.
        scheduleAppRefresh()

        let refreshTask = Task {
            await performRefresh()
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        nonisolated(unsafe) let bgTask = task
        Task {
            let success = await refreshTask.value
            bgTask.setTaskCompleted(success: success)
        }
    }

    /// Returns true when all refresh operations complete successfully.
    @discardableResult
    private func performRefresh() async -> Bool {
        var overallSuccess = true

        // 1. Sync any pending rounds that were saved offline.
        do {
            let synced = try await syncService.syncPendingRounds()
            if synced > 0 {
                print("[BackgroundRefreshService] Synced \(synced) pending round(s).")
            }
        } catch {
            print("[BackgroundRefreshService] Round sync failed: \(error)")
            overallSuccess = false
        }

        // 2. Refresh standings for the active season.
        do {
            if let season = try await syncService.fetchActiveSeason() {
                let _ = try await syncService.fetchStandings(seasonId: season.id)
            }
        } catch {
            print("[BackgroundRefreshService] Standings refresh failed: \(error)")
            overallSuccess = false
        }

        // 3. Pre-fetch nearby course data if we have a recent location.
        // (Location is best-effort in background — skip if unavailable.)
        if let location = LocationCache.lastKnownLocation {
            await courseDataService.prefetchNearbyCourses(
                lat: location.latitude,
                lon: location.longitude,
                radiusKm: 50
            )
        }

        return overallSuccess
    }
}

// MARK: - Location Cache

/// Simple last-known-location store written by `LocationManager` so
/// `BackgroundRefreshService` can use it without importing the GPS module.
///
/// Uses a dedicated boolean key to distinguish "no location saved" from a
/// legitimate fix at (0, 0) in the Gulf of Guinea.
enum LocationCache {
    private static let latKey = "com.thc.lastKnownLat"
    private static let lonKey = "com.thc.lastKnownLon"
    /// Set to true whenever a valid GPS fix has been stored.
    private static let hasLocationKey = "com.thc.hasLastKnownLocation"

    static var lastKnownLocation: (latitude: Double, longitude: Double)? {
        guard UserDefaults.standard.bool(forKey: hasLocationKey) else { return nil }
        let lat = UserDefaults.standard.double(forKey: latKey)
        let lon = UserDefaults.standard.double(forKey: lonKey)
        return (lat, lon)
    }

    static func save(latitude: Double, longitude: Double) {
        UserDefaults.standard.set(latitude, forKey: latKey)
        UserDefaults.standard.set(longitude, forKey: lonKey)
        UserDefaults.standard.set(true, forKey: hasLocationKey)
    }
}
