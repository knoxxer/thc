import Foundation
import AuthenticationServices
import Supabase
import Shared

#if DEBUG

/// Minimal Supabase client for SwiftUI previews.
/// Returns no data and never triggers real network calls.
final class PreviewSupabaseClient: SupabaseClientProviding, @unchecked Sendable {
    let client: SupabaseClient = {
        // Use a dummy URL — no requests will actually be made in previews.
        SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "preview-key")
    }()

    var currentUser: User? {
        get async { nil }
    }

    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws {
        // No-op for previews
    }

    func signOut() async throws {
        // No-op for previews
    }

    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { $0.finish() }
    }
}

#endif
