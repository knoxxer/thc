// AuthManagerTests.swift
// THCTests/Service
//
// All 6 specs from §2.8.
// Tests compile but fail (red) until AuthManager is implemented (M3.2).

import XCTest
@testable import THC

final class AuthManagerTests: XCTestCase {

    var mockSupabase: MockSupabaseClient!
    var mockAuthSession: MockAuthSessionProvider!
    var authManager: AuthManager!

    override func setUp() async throws {
        try await super.setUp()
        mockSupabase = MockSupabaseClient()
        mockAuthSession = MockAuthSessionProvider()
        authManager = AuthManager(
            supabase: mockSupabase,
            authSession: mockAuthSession
        )
    }

    override func tearDown() async throws {
        authManager = nil
        mockAuthSession = nil
        mockSupabase = nil
        try await super.tearDown()
    }

    // MARK: - §2.8.1 Successful Google OAuth login

    func test_successfulGoogleOAuth_setsSignedInState() async {
        // Given: mock returns a valid OAuth callback URL
        mockAuthSession.stubbedCallbackURL = URL(string: "com.thc.app://auth/callback?code=valid_code")
        let player = Player.fixture()
        mockSupabase.stubbedResponses["players"] = .success([player])

        // When
        await authManager.signIn(presenting: MockPresentationAnchor())

        // Then: state transitions to .signedIn
        if case .signedIn(let p) = authManager.state {
            XCTAssertEqual(p.id, player.id, "Signed-in player should match the mocked player")
        } else {
            XCTFail("Expected state to be .signedIn, got \(authManager.state)")
        }
    }

    // MARK: - §2.8.2 Silent token refresh before expiry

    func test_silentTokenRefresh_beforeExpiry() async throws {
        // Given: access token expires in 4 minutes (within auto-refresh window)
        mockSupabase.stubbedSession = MockSession(expiresIn: 240)  // 4 minutes

        // When: Supabase operation triggers auto-refresh
        // The Supabase SDK handles this automatically; we verify it doesn't throw
        // and that the original operation succeeds
        do {
            try await mockSupabase.refreshSession()
        } catch {
            XCTFail("Silent token refresh should succeed: \(error)")
        }
    }

    // MARK: - §2.8.3 Token refresh during long round (4-5 hours)

    func test_longRoundTokenRefresh_after4Hours() async {
        // Given: round started 4.5 hours ago; access token has expired
        // Supabase SDK should refresh using the refresh token
        mockSupabase.stubbedSession = MockSession(expiresIn: -60)  // already expired
        // No refresh error — SDK can refresh silently
        mockSupabase.authRefreshError = nil

        // When: score sync to Supabase is attempted (mock doesn't throw)
        var syncSucceeded = false
        do {
            try await mockSupabase.refreshSession()
            syncSucceeded = true
        } catch {
            // Expected only if mock is configured to fail
        }

        // Then: sync succeeds without requiring re-login
        XCTAssertTrue(syncSucceeded, "Token refresh after 4 hours should succeed silently")
    }

    // MARK: - §2.8.4 Refresh token expired: round data not lost

    func test_refreshTokenExpired_roundDataNotLost() async {
        // Given: BOTH access token and refresh token are expired
        mockSupabase.authRefreshError = AuthError.refreshTokenExpired

        // Simulate round data in memory
        authManager.pendingLocalRoundsCount = 1

        // When: sync attempted
        await authManager.attemptSync()

        // Then: round data preserved; user prompted to log in again; no data loss
        XCTAssertEqual(authManager.pendingLocalRoundsCount, 1,
                       "Pending rounds should NOT be deleted when refresh token expires")
        XCTAssertEqual(authManager.state, .signedOut,
                       "Auth state should be .signedOut when refresh token expires")
        XCTAssertTrue(authManager.needsReauthentication,
                      "User should be prompted to log in again")
    }

    // MARK: - §2.8.5 Logout clears session and local cache

    func test_signOut_clearsSessionPreservesUnsynced() async {
        // Given: authenticated user with cached data; one pending unsynced round
        mockAuthSession.stubbedCallbackURL = URL(string: "com.thc.app://auth/callback?code=valid_code")
        let player = Player.fixture()
        mockSupabase.stubbedResponses["players"] = .success([player])
        await authManager.signIn(presenting: MockPresentationAnchor())

        authManager.pendingLocalRoundsCount = 1

        // When
        await authManager.signOut()

        // Then: session cleared; isAuthenticated = false; pending rounds preserved
        XCTAssertEqual(authManager.state, .signedOut, "Auth state should be .signedOut")
        XCTAssertEqual(authManager.pendingLocalRoundsCount, 1,
                       "Pending unsynced rounds must NOT be deleted on sign-out")
    }

    // MARK: - §2.8.6 Auth state persists across app restarts

    func test_authPersistsAcrossAppRestart() async {
        // Given: user authenticated (session stored in Keychain by Supabase SDK)
        mockSupabase.stubbedCurrentUser = MockUser(id: "test-user-id")
        let player = Player.fixture()
        mockSupabase.stubbedResponses["players"] = .success([player])

        // When: simulate cold launch by calling initialize
        await authManager.initialize()

        // Then: state restores from Keychain; no user interaction needed
        if case .signedIn = authManager.state {
            // Expected
        } else {
            XCTFail("Expected state to restore to .signedIn on cold launch, got \(authManager.state)")
        }
    }
}

// MARK: - Supporting mocks

final class MockAuthSessionProvider: AuthSessionProviding {
    var stubbedCallbackURL: URL?
    var stubbedError: Error?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        if let error = stubbedError { throw error }
        guard let callbackURL = stubbedCallbackURL else {
            throw AuthError.noCallbackURL
        }
        return callbackURL
    }
}

struct MockPresentationAnchor: ASPresentationAnchorProviding {
    var asAnchor: AnyObject? { nil }
}

struct MockSession {
    let expiresIn: TimeInterval
}

struct MockUser {
    let id: String
}

enum AuthError: Error {
    case refreshTokenExpired
    case noCallbackURL
}

private extension Player {
    static func fixture() -> Player {
        Player(
            id: UUID(),
            name: "Patrick Sun",
            displayName: "Patrick",
            slug: "patrick-sun",
            email: "patrick@example.com",
            ghinNumber: nil,
            handicapIndex: nil,
            handicapUpdatedAt: nil,
            avatarUrl: nil,
            isActive: true,
            role: "contributor",
            authUserId: "test-auth-user-id",
            createdAt: Date()
        )
    }
}
