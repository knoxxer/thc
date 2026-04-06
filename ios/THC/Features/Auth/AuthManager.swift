import Foundation
import AuthenticationServices
import Supabase
import Observation
import Shared

// MARK: - AuthManager

/// Manages the full authentication lifecycle.
///
/// Observes Supabase auth events, maps `auth.users` to the `players` table,
/// and exposes a typed `AuthState` to the UI layer.
@Observable
final class AuthManager: @unchecked Sendable {

    // MARK: - AuthState

    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(Player)
        /// Authenticated via Google OAuth but no matching `players` row found.
        case notAPlayer
        /// A network or unexpected error occurred during player resolution (Fix #19).
        case error(String)

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.signedOut, .signedOut): return true
            case (.signedIn(let a), .signedIn(let b)): return a.id == b.id
            case (.notAPlayer, .notAPlayer): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Public State

    private(set) var state: AuthState = .loading

    // MARK: - Private

    private let supabase: SupabaseClientProviding
    private var authStateTask: Task<Void, Never>?

    // MARK: - Init

    init(supabase: SupabaseClientProviding) {
        self.supabase = supabase
        startObservingAuthState()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Public Actions

    /// Initiate Google OAuth sign-in.
    func signIn(presenting anchor: ASPresentationAnchor) async {
        do {
            try await supabase.signInWithGoogle(presenting: anchor)
            // Auth state observer picks up the new session automatically.
        } catch {
            // Sign-in was cancelled or failed — remain on signedOut.
            state = .signedOut
        }
    }

    /// Sign out and clear the local session.
    func signOut() async {
        do {
            try await supabase.signOut()
        } catch {
            // Best effort — the auth state observer will still react.
        }
        state = .signedOut
    }

    // MARK: - Auth State Observer

    private func startObservingAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            // On launch, resolve the persisted session first.
            await resolveCurrentSession()

            // Then watch for future changes (sign-in, sign-out, token refresh).
            let stream = supabase.authStateChanges()
            for await event in stream {
                await handleAuthEvent(event)
            }
        }
    }

    private func resolveCurrentSession() async {
        guard let user = await supabase.currentUser else {
            state = .signedOut
            return
        }
        await resolvePlayer(for: user)
    }

    private func handleAuthEvent(_ event: AuthChangeEvent) async {
        switch event {
        case .signedIn, .tokenRefreshed, .userUpdated:
            if let user = await supabase.currentUser {
                await resolvePlayer(for: user)
            } else {
                state = .signedOut
            }
        case .signedOut:
            state = .signedOut
        default:
            break
        }
    }

    // MARK: - Player Resolution

    /// Looks up the `players` row for a newly authenticated user.
    ///
    /// Two-step lookup: primary on `auth_user_id`, fallback on `email`.
    /// The email fallback handles accounts created before `auth_user_id` was populated
    /// in the `players` table. Network errors surface as `.error` rather than `.notAPlayer`
    /// so the UI can offer a retry rather than permanently blocking the user.
    private func resolvePlayer(for user: Supabase.User) async {
        do {
            // Primary lookup: match on auth_user_id
            let byAuthId: [Player] = try await supabase.client
                .from("players")
                .select()
                .eq("auth_user_id", value: user.id.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            if let player = byAuthId.first {
                state = .signedIn(player)
                return
            }

            // Fallback: match by email (handles accounts predating auth_user_id population)
            let email = user.email ?? ""
            guard !email.isEmpty else {
                state = .notAPlayer
                return
            }

            let byEmail: [Player] = try await supabase.client
                .from("players")
                .select()
                .eq("email", value: email)
                .limit(1)
                .execute()
                .value

            if let player = byEmail.first {
                state = .signedIn(player)
            } else {
                state = .notAPlayer
            }
        } catch let urlError as URLError {
            // Fix #19: Distinguish network errors from "not a player".
            state = .error("Network error: \(urlError.localizedDescription)")
        } catch {
            // Non-network errors (e.g., decoding) -- still surface the error.
            state = .error(error.localizedDescription)
        }
    }
}
