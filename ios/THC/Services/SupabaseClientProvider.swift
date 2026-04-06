import Foundation
import Supabase
import AuthenticationServices

// MARK: - Protocol

/// Injectable abstraction over the Supabase client for testing.
/// iOS-only — the watch target uses WatchConnectivity and does not talk to Supabase directly.
protocol SupabaseClientProviding: Sendable {
    /// The underlying Supabase client for direct queries.
    var client: SupabaseClient { get }

    /// The currently authenticated user, or nil if signed out.
    var currentUser: User? { get async }

    /// Sign in with Google OAuth via ASWebAuthenticationSession.
    /// The SDK drives the OAuth redirect flow and updates the session internally.
    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws

    /// Sign out and clear the local session from Keychain.
    func signOut() async throws

    /// Observe auth state changes as an async stream.
    func authStateChanges() -> AsyncStream<AuthChangeEvent>
}

// MARK: - Implementation

/// Concrete Supabase client provider.
/// Loads the Supabase URL and anon key from Secrets.plist at runtime.
/// Token refresh is handled automatically by the Supabase Swift SDK's autoRefreshToken
/// option. The SDK stores the refresh token in Keychain, so a 4-5 hour round will
/// silently refresh without any code on our part.
final class SupabaseClientProvider: SupabaseClientProviding, @unchecked Sendable {

    // MARK: - Static Factory

    /// Shared singleton. Use this in production code.
    static let shared: SupabaseClientProvider = {
        do {
            return try SupabaseClientProvider()
        } catch {
            fatalError("Failed to initialize SupabaseClientProvider: \(error)")
        }
    }()

    // MARK: - Public

    let client: SupabaseClient

    // MARK: - Init

    /// Initializes by reading SUPABASE_URL and SUPABASE_ANON_KEY from Secrets.plist.
    /// Secrets.plist is excluded from git via .gitignore. Copy Secrets.plist.example
    /// and fill in real values before building.
    init() throws {
        let secrets = try SupabaseClientProvider.loadSecrets()
        guard let urlString = secrets["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            throw SupabaseConfigError.missingKey("SUPABASE_URL")
        }
        guard let anonKey = secrets["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty else {
            throw SupabaseConfigError.missingKey("SUPABASE_ANON_KEY")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    autoRefreshToken: true
                )
            )
        )
    }

    // MARK: - SupabaseClientProviding

    var currentUser: User? {
        get async {
            try? await client.auth.session.user
        }
    }

    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "com.thc.app://auth/callback")
        ) { session in
            session.presentationContextProvider = AnchorPresentationContext(anchor: anchor)
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in await client.auth.authStateChanges {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private

    private static func loadSecrets() throws -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            throw SupabaseConfigError.secretsFileNotFound
        }
        return plist
    }
}

// MARK: - ASWebAuthenticationSession Presentation Context

private final class AnchorPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}

// MARK: - Errors

enum SupabaseConfigError: LocalizedError {
    case secretsFileNotFound
    case missingKey(String)

    var errorDescription: String? {
        switch self {
        case .secretsFileNotFound:
            return "Secrets.plist not found. Copy Secrets.plist.example and fill in your Supabase credentials."
        case .missingKey(let key):
            return "Required key '\(key)' is missing or empty in Secrets.plist."
        }
    }
}
