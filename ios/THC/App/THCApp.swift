import SwiftUI
import SwiftData
import Shared

/// App entry point. Wires up the service graph and injects it into the SwiftUI environment.
///
/// Service ownership: `THCApp` owns the `ModelContainer`, `SyncService`,
/// `CourseDataService`, and `LocationManager`. They are long-lived and injected
/// into the view hierarchy via `ContentView` rather than the environment to keep
/// the dependency graph explicit.
@main
struct THCApp: App {
    @State private var authManager: AuthManager

    private let modelContainer: ModelContainer
    private let syncService: SyncServiceProviding
    private let courseDataService: CourseDataServiceProviding
    private let locationManager: LocationManager
    private let supabase: SupabaseClientProviding

    init() {
        // Supabase client — credentials loaded from Secrets.plist at runtime
        let client = SupabaseClientProvider.shared
        supabase = client

        // SwiftData container
        let schema = OfflineStorageSchema.current
        let modelConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: modelConfig)
            modelContainer = container

            // Service graph
            let offlineStorage = OfflineStorage(context: container.mainContext)
            syncService = SyncService(supabase: client, storage: offlineStorage)
            courseDataService = CourseDataService(
                supabase: client,
                storage: offlineStorage,
                overpass: OverpassAPIClient(),
                golfCourseAPI: GolfCourseAPIClient()
            )
        } catch {
            fatalError("SwiftData ModelContainer failed to initialize: \(error)")
        }

        locationManager = LocationManager()
        _authManager = State(initialValue: AuthManager(supabase: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                syncService: syncService,
                courseDataService: courseDataService,
                locationManager: locationManager,
                supabase: supabase
            )
            .environment(authManager)
            .environment(locationManager)
            .modelContainer(modelContainer)
        }
    }
}
