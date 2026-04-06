// MockSupabaseClient.swift
// THCTests/Mocks
//
// Implements SupabaseClientProviding for unit/service tests.
// Captures all write operations; stubs reads by table name.
// Tests assert on insertCalls, updateCalls, deleteCalls to prevent
// unexpected I/O.

import Foundation
@testable import THC

// MARK: - Protocol (mirrors production interface)

// NOTE: The production SupabaseClientProviding protocol is defined in
// THC/Services/SupabaseClientProvider.swift. This mock satisfies it
// so it can be injected anywhere the protocol is expected.

final class MockSupabaseClient: SupabaseClientProviding {

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

    var stubbedCurrentUser: (any Sendable)?  // Stub for auth user
    var stubbedSession: (any Sendable)?      // Stub for auth session
    var authRefreshError: Error?             // Set to test refresh failure

    // MARK: - SupabaseClientProviding conformance

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
