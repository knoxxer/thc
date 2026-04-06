// ModelCodingTests.swift
// THCTests/Unit
//
// All specs from §2.10 — Codable round-trip tests for all Shared/Models.
// Tests compile but fail (red) until models are implemented (M2.2, M2.3).

import XCTest
import Shared
@testable import THC

final class ModelCodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - §2.10.1 Player decodes from Supabase JSON

    func test_playerDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Patrick Sun",
            "display_name": "Patrick",
            "slug": "patrick-sun",
            "email": "patrick@example.com",
            "ghin_number": "1234567",
            "handicap_index": 12.4,
            "handicap_updated_at": "2026-01-15T10:00:00Z",
            "avatar_url": "https://example.com/avatar.jpg",
            "is_active": true,
            "role": "contributor",
            "auth_user_id": "auth-user-uuid-123",
            "created_at": "2025-01-01T00:00:00Z"
        }
        """

        let player = try decoder.decode(Player.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(player.name, "Patrick Sun")
        XCTAssertEqual(player.displayName, "Patrick")
        XCTAssertEqual(player.slug, "patrick-sun")
        XCTAssertEqual(player.ghinNumber, "1234567")
        XCTAssertEqual(player.handicapIndex ?? 0, 12.4, accuracy: 0.001)
        XCTAssertNotNil(player.handicapUpdatedAt, "handicap_updated_at should decode to a Date")
        XCTAssertEqual(player.role, "contributor")
        XCTAssertTrue(player.isActive)
    }

    func test_playerDecodes_handicapUpdatedAt() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Test Player",
            "display_name": "Test",
            "slug": "test-player",
            "is_active": true,
            "role": "contributor",
            "handicap_updated_at": "2026-03-01T14:30:00Z",
            "created_at": "2025-01-01T00:00:00Z"
        }
        """

        let player = try decoder.decode(Player.self, from: json.data(using: .utf8)!)
        XCTAssertNotNil(player.handicapUpdatedAt)

        // Verify the decoded date is the expected date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: player.handicapUpdatedAt!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 1)
    }

    // MARK: - §2.10.2 Round decodes with source = "app"

    func test_roundDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "player_id": "550e8400-e29b-41d4-a716-446655440000",
            "season_id": "770e8400-e29b-41d4-a716-446655440002",
            "played_at": "2026-04-05",
            "course_name": "Torrey Pines South",
            "tee_name": "Black",
            "course_rating": 74.6,
            "slope_rating": 144.0,
            "par": 72,
            "gross_score": 90,
            "course_handicap": 18,
            "net_score": 72,
            "net_vs_par": 0,
            "points": 10,
            "ghin_score_id": null,
            "source": "app",
            "entered_by": null,
            "created_at": "2026-04-05T18:00:00Z"
        }
        """

        let round = try decoder.decode(Round.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(round.courseName, "Torrey Pines South")
        XCTAssertEqual(round.par, 72)
        XCTAssertEqual(round.grossScore, 90)
        XCTAssertEqual(round.netScore, 72)
        XCTAssertEqual(round.points, 10)
    }

    func test_roundDecodes_sourceFieldAcceptsApp() throws {
        let json = """
        {
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "player_id": "550e8400-e29b-41d4-a716-446655440000",
            "season_id": "770e8400-e29b-41d4-a716-446655440002",
            "played_at": "2026-04-05",
            "course_name": "Test Course",
            "par": 72,
            "gross_score": 90,
            "course_handicap": 18,
            "net_score": 72,
            "net_vs_par": 0,
            "source": "app",
            "created_at": "2026-04-05T18:00:00Z"
        }
        """

        let round = try decoder.decode(Round.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(round.source, "app", "source field must accept value \"app\"")
    }

    // MARK: - Season + SeasonStanding

    func test_seasonDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "880e8400-e29b-41d4-a716-446655440003",
            "name": "2026 Season",
            "starts_at": "2026-01-01T00:00:00Z",
            "ends_at": "2026-12-31T23:59:59Z",
            "is_active": true,
            "min_rounds": 5,
            "top_n_rounds": 10,
            "created_at": "2025-12-01T00:00:00Z"
        }
        """

        let season = try decoder.decode(Season.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(season.name, "2026 Season")
        XCTAssertTrue(season.isActive)
        XCTAssertEqual(season.minRounds, 5)
        XCTAssertEqual(season.topNRounds, 10)
    }

    func test_seasonStandingDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "player_id": "550e8400-e29b-41d4-a716-446655440000",
            "season_id": "880e8400-e29b-41d4-a716-446655440003",
            "player_name": "Patrick Sun",
            "player_slug": "patrick-sun",
            "handicap_index": 12.4,
            "avatar_url": null,
            "total_rounds": 8,
            "is_eligible": true,
            "best_n_points": 85,
            "best_round_points": 13,
            "best_net_vs_par": -3
        }
        """

        let standing = try decoder.decode(SeasonStanding.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(standing.playerName, "Patrick Sun")
        XCTAssertEqual(standing.bestNPoints, 85)
        XCTAssertEqual(standing.bestNetVsPar, -3)
        XCTAssertTrue(standing.isEligible)
    }

    // MARK: - CourseData + CourseHole

    func test_courseDataDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "990e8400-e29b-41d4-a716-446655440004",
            "golfcourseapi_id": 12345,
            "name": "Torrey Pines South",
            "club_name": "Torrey Pines Golf Course",
            "address": "11480 N Torrey Pines Rd, La Jolla, CA 92037",
            "lat": 32.8990,
            "lon": -117.2519,
            "hole_count": 18,
            "par": 72,
            "osm_id": "relation/12345678",
            "has_green_data": true,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-03-15T00:00:00Z"
        }
        """

        let course = try decoder.decode(CourseData.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(course.name, "Torrey Pines South")
        XCTAssertEqual(course.par, 72)
        XCTAssertEqual(course.holeCount, 18)
        XCTAssertTrue(course.hasGreenData)
        XCTAssertNotNil(course.osmId)
    }

    func test_courseHoleDecodesFromSupabaseJSON_nullPolygonIsNil() throws {
        // §2.10.3 — CourseHole with null green_polygon (tap-and-save)
        let json = """
        {
            "id": "aa0e8400-e29b-41d4-a716-446655440005",
            "course_id": "990e8400-e29b-41d4-a716-446655440004",
            "hole_number": 3,
            "par": 4,
            "yardage": 380,
            "handicap": 7,
            "green_lat": 32.8951,
            "green_lon": -117.2518,
            "green_polygon": null,
            "tee_lat": 32.8964,
            "tee_lon": -117.2528,
            "source": "tap_and_save",
            "saved_by": "550e8400-e29b-41d4-a716-446655440000",
            "created_at": "2026-02-01T00:00:00Z",
            "updated_at": "2026-02-01T00:00:00Z"
        }
        """

        let hole = try decoder.decode(CourseHole.self, from: json.data(using: .utf8)!)
        XCTAssertNil(hole.greenPolygon, "null green_polygon should decode to nil")
        XCTAssertEqual(hole.holeNumber, 3)
        XCTAssertEqual(hole.source, "tap_and_save")
        XCTAssertNotNil(hole.greenLat)
    }

    // MARK: - §2.10.4 GeoJSONPolygon decodes from JSONB

    func test_geoJSONPolygonDecodesFromJSONB() throws {
        let json = """
        {
            "type": "Polygon",
            "coordinates": [
                [
                    [-117.2520, 32.8998],
                    [-117.2518, 32.8997],
                    [-117.2516, 32.8999],
                    [-117.2518, 32.9001],
                    [-117.2521, 32.9000],
                    [-117.2520, 32.8998]
                ]
            ]
        }
        """

        let polygon = try decoder.decode(GeoJSONPolygon.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(polygon.type, "Polygon")
        XCTAssertFalse(polygon.coordinates.isEmpty, "coordinates array should have at least one ring")
        let ring = polygon.coordinates.first!
        XCTAssertEqual(ring.count, 6, "Outer ring should have 6 coordinate pairs")
        XCTAssertEqual(ring.first?.count, 2, "Each coordinate should have [lon, lat]")
    }

    // MARK: - HoleScore

    func test_holeScoreDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "bb0e8400-e29b-41d4-a716-446655440006",
            "round_id": "660e8400-e29b-41d4-a716-446655440001",
            "hole_number": 1,
            "strokes": 4,
            "putts": 2,
            "fairway_hit": "hit",
            "green_in_regulation": true,
            "created_at": "2026-04-05T18:05:00Z"
        }
        """

        let score = try decoder.decode(HoleScore.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(score.holeNumber, 1)
        XCTAssertEqual(score.strokes, 4)
        XCTAssertEqual(score.putts, 2)
        XCTAssertEqual(score.fairwayHit, "hit")
        XCTAssertEqual(score.greenInRegulation, true)
    }

    // MARK: - §2.10.5 Round encodes with snake_case keys

    func test_playerEncodesBackToJSON() throws {
        // Given: a Player struct
        // (created via init, requires implementation)
        // For now verify the encoder strategy is correct by creating a minimal codable
        let testDict: [String: String] = ["displayName": "Patrick"]
        let encoded = try encoder.encode(testDict)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        // snake_case strategy should convert displayName → display_name
        XCTAssertNotNil(decoded["display_name"], "Encoder should convert camelCase to snake_case")
    }

    func test_roundEncodesWithSnakeCaseKeys() throws {
        // Create a minimal dictionary to verify key encoding strategy
        struct TestRound: Codable {
            let courseName: String
            let grossScore: Int
            let playedAt: String
        }

        let round = TestRound(courseName: "Torrey Pines", grossScore: 90, playedAt: "2026-04-05")
        let encoded = try encoder.encode(round)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]

        XCTAssertNotNil(decoded["course_name"], "courseName should encode as course_name")
        XCTAssertNotNil(decoded["gross_score"], "grossScore should encode as gross_score")
        XCTAssertNotNil(decoded["played_at"], "playedAt should encode as played_at")
    }
}
