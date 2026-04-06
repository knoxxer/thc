// MockSupabaseClient.swift
// THCTests/Mocks
//
// Implements SupabaseClientProviding for unit/service tests.
// Wraps a real SupabaseClient pointed at loopback so protocol conformance
// compiles. Tests use the mock-specific helper properties (insertCalls,
// updateCalls, etc.) to assert on behavior without hitting a real backend.

import Foundation
import Supabase
import AuthenticationServices
@testable import THC

// MARK: - Mock

final class MockSupabaseClient: SupabaseClientProviding, @unchecked Sendable {

    // MARK: - SupabaseClientProviding conformance

    let client: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: "http://127.0.0.1:54321")!,
        supabaseKey: "test-anon-key"
    )

    var currentUser: User? {
        get async { nil }
    }

    func signInWithGoogle(presenting anchor: ASPresentationAnchor) async throws {
        // No-op in tests
    }

    func signOut() async throws {
        // No-op in tests
    }

    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - Captured calls (assert on these in tests)

    struct InsertCall {
        let table: String
        let payload: Any
    }

    struct UpdateCall {
        let table: String
        let payload: Any
        let matchColumn: String?
        let matchValue: Any?
    }

    struct DeleteCall {
        let table: String
        let matchColumn: String
        let matchValue: Any
    }

    struct UpsertCall {
        let table: String
        let payload: Any
    }

    var insertCalls: [InsertCall] = []
    var updateCalls: [UpdateCall] = []
    var deleteCalls: [DeleteCall] = []
    var upsertCalls: [UpsertCall] = []

    // MARK: - Stubbed responses

    /// Key: table name. Value: Result to return for select/fetch operations.
    var stubbedResponses: [String: Result<Any, Error>] = [:]

    /// Error to throw on next insert (if set). Cleared after use.
    var insertError: Error?

    /// Error to throw on next upsert (if set). Cleared after use.
    var upsertError: Error?

    // MARK: - Auth stubs

    var stubbedCurrentUser: (any Sendable)?
    var stubbedSession: (any Sendable)?
    var authRefreshError: Error?

    // MARK: - Mock helper methods (used by tests)

    func insert(into table: String, payload: Any) async throws {
        if let error = insertError {
            insertError = nil
            throw error
        }
        insertCalls.append(InsertCall(table: table, payload: payload))
    }

    func upsert(into table: String, payload: Any) async throws {
        if let error = upsertError {
            upsertError = nil
            throw error
        }
        upsertCalls.append(UpsertCall(table: table, payload: payload))
    }

    func update(
        table: String,
        payload: Any,
        matchColumn: String?,
        matchValue: Any?
    ) async throws {
        updateCalls.append(
            UpdateCall(
                table: table,
                payload: payload,
                matchColumn: matchColumn,
                matchValue: matchValue
            )
        )
    }

    func delete(
        from table: String,
        matchColumn: String,
        matchValue: Any
    ) async throws {
        deleteCalls.append(
            DeleteCall(
                table: table,
                matchColumn: matchColumn,
                matchValue: matchValue
            )
        )
    }

    func select<T: Decodable & Sendable>(
        from table: String,
        type: T.Type
    ) async throws -> [T] {
        switch stubbedResponses[table] {
        case .success(let value):
            if let typed = value as? [T] {
                return typed
            }
            return []
        case .failure(let error):
            throw error
        case nil:
            return []
        }
    }

    func selectFirst<T: Decodable & Sendable>(
        from table: String,
        type: T.Type
    ) async throws -> T? {
        switch stubbedResponses[table] {
        case .success(let value):
            if let typed = value as? T {
                return typed
            }
            if let array = value as? [T] {
                return array.first
            }
            return nil
        case .failure(let error):
            throw error
        case nil:
            return nil
        }
    }

    // MARK: - Auth helpers

    func refreshSession() async throws {
        if let error = authRefreshError {
            throw error
        }
    }

    // MARK: - Reset

    func reset() {
        insertCalls.removeAll()
        updateCalls.removeAll()
        deleteCalls.removeAll()
        upsertCalls.removeAll()
        stubbedResponses.removeAll()
        insertError = nil
        upsertError = nil
        authRefreshError = nil
        stubbedCurrentUser = nil
        stubbedSession = nil
    }
}
