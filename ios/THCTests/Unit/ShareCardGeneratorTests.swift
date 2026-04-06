// ShareCardGeneratorTests.swift
// THCTests/Unit
//
// Specs 2.16.1-2.16.2 -- ShareCardGenerator UIImage generation.
// Tests compile but fail (red) until ShareCardGenerator is implemented (M13.7).

import XCTest
import Shared
@testable import THC

@MainActor
final class ShareCardGeneratorTests: XCTestCase {

    // MARK: - §2.16.1 Generate image returns non-nil image

    func test_generateImage_returnsNonNilImage() {
        // Given: valid Player, Round, and array of HoleScores
        let player = Player.fixture()
        let round = Round.fixture()
        let holeScores = HoleScore.fixtures(count: 18)

        // When
        let image = ShareCardGenerator.generateImage(
            player: player,
            round: round,
            holeScores: holeScores
        )

        // Then: returned UIImage has size > 0
        XCTAssertGreaterThan(image.size.width, 0, "Generated image width must be > 0")
        XCTAssertGreaterThan(image.size.height, 0, "Generated image height must be > 0")
    }

    // MARK: - §2.16.2 Generate image with nil hole scores: no crash

    func test_generateImage_withNilHoleScores_nocrash() {
        // Given: valid Player and Round; holeScores is nil
        let player = Player.fixture()
        let round = Round.fixture()

        // When / Then: no crash
        let image = ShareCardGenerator.generateImage(
            player: player,
            round: round,
            holeScores: nil
        )

        // Returned UIImage has size > 0
        XCTAssertGreaterThan(image.size.width, 0, "Generated image width must be > 0")
    }
}

// MARK: - Fixtures

private extension Player {
    static func fixture() -> Player {
        Player(
            id: UUID(),
            name: "Patrick Sun",
            displayName: "Patrick",
            slug: "patrick-sun",
            email: "patrick@example.com",
            ghinNumber: "1234567",
            handicapIndex: 12.4,
            handicapUpdatedAt: Date(),
            avatarUrl: nil,
            isActive: true,
            role: "contributor",
            authUserId: nil,
            createdAt: Date()
        )
    }
}

private extension Round {
    static func fixture() -> Round {
        Round(
            id: UUID(),
            playerId: UUID(),
            seasonId: UUID(),
            playedAt: "2026-04-05",
            courseName: "Torrey Pines South",
            teeName: "Black",
            courseRating: 74.6,
            slopeRating: 144.0,
            par: 72,
            grossScore: 87,
            courseHandicap: 15,
            netScore: 72,
            netVsPar: 0,
            points: 10,
            ghinScoreId: nil,
            source: "app",
            enteredBy: nil,
            createdAt: Date()
        )
    }
}

private extension HoleScore {
    static func fixtures(count: Int) -> [HoleScore] {
        (1...count).map { i in
            HoleScore(
                id: UUID(),
                roundId: UUID(),
                holeNumber: i,
                strokes: 4,
                putts: 2,
                fairwayHit: "hit",
                greenInRegulation: i % 3 == 0,
                createdAt: Date()
            )
        }
    }
}
