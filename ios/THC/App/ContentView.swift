import SwiftUI
import Shared

/// Root view. Shows LoginView when unauthenticated, tab bar when signed in.
struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    let syncService: SyncServiceProviding
    let courseDataService: CourseDataServiceProviding
    let locationManager: LocationManager
    let supabase: SupabaseClientProviding

    var body: some View {
        switch authManager.state {
        case .loading:
            loadingView
        case .signedOut:
            LoginView()
        case .notAPlayer:
            notAPlayerView
        case .error(let message):
            errorView(message: message)
        case .signedIn(let player):
            MainTabView(
                player: player,
                syncService: syncService,
                courseDataService: courseDataService,
                locationManager: locationManager,
                supabase: supabase
            )
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text("Loading…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Connection Error")
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task {
                    // Re-trigger session resolution
                    await authManager.signOut()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var notAPlayerView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Not a Player")
                .font(.title2.bold())
            Text("Your account doesn't have a player profile. Contact an admin to be added.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Sign Out") {
                Task { await authManager.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - MainTabView

private struct MainTabView: View {
    let player: Player
    let syncService: SyncServiceProviding
    let courseDataService: CourseDataServiceProviding
    let locationManager: LocationManager
    let supabase: SupabaseClientProviding

    @State private var feedViewModel: FeedViewModel?

    var body: some View {
        TabView {
            // Tab 1: Standings
            NavigationStack {
                LeaderboardView(player: player, syncService: syncService)
            }
            .tabItem {
                Label("Standings", systemImage: "list.number")
            }

            // Tab 2: Feed
            NavigationStack {
                if let vm = feedViewModel {
                    FeedView(viewModel: vm)
                } else {
                    ProgressView()
                        .task {
                            feedViewModel = FeedViewModel(
                                socialService: SocialService(supabase: supabase),
                                syncService: syncService,
                                player: player
                            )
                        }
                }
            }
            .tabItem {
                Label("Feed", systemImage: "bubble.left.and.bubble.right")
            }

            // Tab 3: New Round (course search)
            NavigationStack {
                CourseSearchViewPlaceholder(
                    player: player,
                    courseDataService: courseDataService,
                    locationManager: locationManager,
                    syncService: syncService
                )
                .navigationTitle("New Round")
            }
            .tabItem {
                Label("New Round", systemImage: "plus.circle.fill")
            }

            // Tab 4: Profile
            NavigationStack {
                PlayerDetailView(
                    player: player,
                    isCurrentUser: true,
                    viewModel: StandingsViewModel(syncService: syncService)
                )
                .navigationTitle("Profile")
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
    }
}

// MARK: - CourseSearchViewPlaceholder
//
// Wraps CourseSearchView to load the active season before displaying it.
// NoOpOfflineStorage is used here — PostRoundView creates its own OfflineStorage
// when invoked. For a small group app this is acceptable.
private struct CourseSearchViewPlaceholder: View {
    let player: Player
    let courseDataService: CourseDataServiceProviding
    let locationManager: LocationManager
    let syncService: SyncServiceProviding

    @State private var season: Season?

    var body: some View {
        CourseSearchView(
            player: player,
            courseDataService: courseDataService,
            locationManager: locationManager,
            offlineStorage: NoOpOfflineStorage(),
            syncService: syncService,
            season: season
        )
        .task {
            season = try? await syncService.fetchActiveSeason()
        }
    }
}
