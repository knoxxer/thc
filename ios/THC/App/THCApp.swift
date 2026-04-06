import SwiftUI
import SwiftData
import Shared

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
