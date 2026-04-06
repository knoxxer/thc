// MockURLSession.swift
// THCTests/Mocks
//
// URLSessionProtocol conformer that stubs HTTP responses by URL.
// Supports both data stubs and error injection.
// Used for OverpassAPIClient and GolfCourseAPIClient tests.

import Foundation
@testable import THC

// MARK: - Protocol

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - Mock

final class MockURLSession: URLSessionProtocol {

    // MARK: - Stubs

    /// Keyed by URL string. Value is the (Data, HTTPURLResponse) to return.
    var stubbedData: [String: (Data, HTTPURLResponse)] = [:]

    /// Keyed by URL string. Error to throw instead of returning data.
    var stubbedErrors: [String: Error] = [:]

    // MARK: - Captured requests (assert on these in tests)

    var capturedRequests: [URLRequest] = []

    // MARK: - URLSessionProtocol

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)

        let urlString = request.url?.absoluteString ?? ""

        // Check for stubbed errors first
        if let error = stubbedErrors[urlString] {
            throw error
        }

        // Check for exact URL match
        if let stub = stubbedData[urlString] {
            return (stub.0, stub.1)
        }

        // Check for partial URL match (e.g., Overpass endpoint regardless of query body)
        for (key, stub) in stubbedData {
            if urlString.contains(key) || key.contains(urlString) {
                return (stub.0, stub.1)
            }
        }

        // No stub found — fail fast so tests are explicit about what they mock
        throw URLError(.unsupportedURL,
                       userInfo: [NSLocalizedDescriptionKey: "MockURLSession: no stub for \(urlString)"])
    }

    // MARK: - Helpers

    /// Load a fixture file from THCTests/Fixtures/ and stub it for the given URL.
    func stubFixture(named filename: String, forURL url: String, statusCode: Int = 200) throws {
        guard let fixtureURL = Bundle(for: MockURLSession.self)
            .url(forResource: filename, withExtension: nil) else {
            throw TestError.fixtureNotFound(filename)
        }
        let data = try Data(contentsOf: fixtureURL)
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        stubbedData[url] = (data, response)
    }

    /// Stub with raw Data directly (for inline JSON in tests).
    func stubData(_ data: Data, forURL url: String, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        stubbedData[url] = (data, response)
    }

    /// Stub with a JSON-encodable value.
    func stubJSON<T: Encodable>(_ value: T, forURL url: String, statusCode: Int = 200) throws {
        let data = try JSONEncoder().encode(value)
        stubData(data, forURL: url, statusCode: statusCode)
    }

    func reset() {
        stubbedData.removeAll()
        stubbedErrors.removeAll()
        capturedRequests.removeAll()
    }
}

// MARK: - Test Error

enum TestError: Error, LocalizedError {
    case fixtureNotFound(String)
    case unexpectedCall(String)

    var errorDescription: String? {
        switch self {
        case .fixtureNotFound(let name):
            return "Test fixture '\(name)' not found in bundle"
        case .unexpectedCall(let message):
            return "Unexpected call: \(message)"
        }
    }
}
