import Foundation

// MARK: - Protocol

/// Injectable interface for the GolfCourseAPI.com REST API.
protocol GolfCourseAPIProviding: Sendable {
    /// Search for courses by name.
    func searchCourses(query: String) async throws -> [GolfCourseAPIResult]

    /// Fetch full course detail by GolfCourseAPI ID.
    func getCourse(id: Int) async throws -> GolfCourseAPIDetail?
}

// MARK: - Response Types

struct GolfCourseAPIResult: Codable, Sendable {
    let id: Int
    let clubName: String
    let courseName: String
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct GolfCourseAPIDetail: Codable, Sendable {
    let id: Int
    let clubName: String
    let courseName: String
    let holes: Int
    let par: Int
    let tees: [GolfCourseAPITee]
    let scorecard: [GolfCourseAPIHole]
}

struct GolfCourseAPITee: Codable, Sendable {
    let teeName: String
    let courseRating: Double
    let slopeRating: Int
    let totalYardage: Int
}

struct GolfCourseAPIHole: Codable, Sendable {
    let holeNumber: Int
    let par: Int
    let yardage: Int
    let handicap: Int
}

// MARK: - Rate Limit

/// Persists the daily request count and reset date to UserDefaults.
/// Free tier limit: 300 requests/day.  We begin returning cached results above 250
/// to preserve a safety margin.
struct GolfCourseAPIRateLimit {
    private static let countKey = "com.thc.golfcourseapi.dailyCount"
    private static let resetKey = "com.thc.golfcourseapi.resetDate"
    private static let dailyLimit = 300
    private static let softLimit = 250

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns true when requests are still allowed (below the soft limit).
    var canMakeRequest: Bool {
        resetIfNewDay()
        return dailyCount < Self.softLimit
    }

    /// Increment the request count by 1.
    mutating func recordRequest() {
        resetIfNewDay()
        defaults.set(dailyCount + 1, forKey: Self.countKey)
    }

    var dailyCount: Int {
        defaults.integer(forKey: Self.countKey)
    }

    private func resetIfNewDay() {
        let stored = defaults.object(forKey: Self.resetKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(stored) {
            defaults.set(0, forKey: Self.countKey)
            defaults.set(Date.now, forKey: Self.resetKey)
        }
    }
}

// MARK: - Errors

enum GolfCourseAPIError: LocalizedError {
    case rateLimitExceeded
    case apiKeyUnavailable
    case requestFailed(Int)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "GolfCourseAPI daily limit (300 requests) reached. Try again tomorrow."
        case .apiKeyUnavailable:
            return "GolfCourseAPI key is not yet available. It will be fetched from Supabase on next launch."
        case .requestFailed(let code):
            return "GolfCourseAPI request failed with HTTP \(code)."
        case .parseError(let detail):
            return "Failed to parse GolfCourseAPI response: \(detail)"
        }
    }
}

// MARK: - Implementation

final class GolfCourseAPIClient: GolfCourseAPIProviding, @unchecked Sendable {
    private static let baseURL = "https://api.golfcourseapi.com/v1"

    private let session: URLSession
    private var rateLimit: GolfCourseAPIRateLimit
    private var apiKey: String?

    /// Injectable URLSession for testing — defaults to the shared session.
    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.rateLimit = GolfCourseAPIRateLimit(defaults: defaults)
    }

    // MARK: - API Key Management

    /// Set the API key. Called by `CourseDataService` once it has been fetched from
    /// the `app_config` Supabase table (and optionally cached to Keychain).
    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - GolfCourseAPIProviding

    func searchCourses(query: String) async throws -> [GolfCourseAPIResult] {
        guard let key = apiKey, !key.isEmpty else {
            throw GolfCourseAPIError.apiKeyUnavailable
        }
        guard rateLimit.canMakeRequest else {
            throw GolfCourseAPIError.rateLimitExceeded
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(Self.baseURL)/courses?search=\(encodedQuery)") else {
            throw GolfCourseAPIError.parseError("Could not construct search URL")
        }

        let data = try await performRequest(url: url, apiKey: key)
        rateLimit.recordRequest()

        // The GolfCourseAPI search endpoint returns a top-level object with a
        // "courses" array.
        do {
            let wrapper = try JSONDecoder.snakeCase.decode(SearchResponse.self, from: data)
            return wrapper.courses
        } catch {
            throw GolfCourseAPIError.parseError(error.localizedDescription)
        }
    }

    func getCourse(id: Int) async throws -> GolfCourseAPIDetail? {
        guard let key = apiKey, !key.isEmpty else {
            throw GolfCourseAPIError.apiKeyUnavailable
        }
        guard rateLimit.canMakeRequest else {
            throw GolfCourseAPIError.rateLimitExceeded
        }

        guard let url = URL(string: "\(Self.baseURL)/courses/\(id)") else {
            throw GolfCourseAPIError.parseError("Could not construct detail URL")
        }

        let data = try await performRequest(url: url, apiKey: key)
        rateLimit.recordRequest()

        do {
            let detail = try JSONDecoder.snakeCase.decode(GolfCourseAPIDetail.self, from: data)
            return detail
        } catch {
            throw GolfCourseAPIError.parseError(error.localizedDescription)
        }
    }

    // MARK: - HTTP

    private func performRequest(url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw GolfCourseAPIError.rateLimitExceeded
            }
            guard (200...299).contains(http.statusCode) else {
                throw GolfCourseAPIError.requestFailed(http.statusCode)
            }
        }

        return data
    }

    // MARK: - Response Wrappers

    private struct SearchResponse: Decodable {
        let courses: [GolfCourseAPIResult]
    }
}

// MARK: - JSONDecoder Helper

private extension JSONDecoder {
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
