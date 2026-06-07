//
//  GammaServicesTests.swift
//  FollowerTests
//
//  Gamma Premium 服务测试：Scoring, Comparison, Prediction。

import XCTest
@testable import Follower

final class GammaServicesTests: XCTestCase {

    // MARK: - ScoringService

    func testScoringWithDataReturnsValidScore() async {
        let service = ScoringService()
        let snapshots = [
            makeSnapshot(likes: 100, comments: 20, shares: 10, views: 1000),
            makeSnapshot(likes: 200, comments: 30, shares: 15, views: 2000),
        ]
        let result = await service.scoreEngagement(snapshots: snapshots)
        XCTAssertGreaterThan(result.score, 0, "Score should be positive with engagement data")
        XCTAssertLessThanOrEqual(result.score, 100, "Score should be <= 100")
    }

    func testScoringEmptyReturnsZero() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [])
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.label, "No data")
    }

    func testScoringCommentsWeightedHigherThanLikes() async {
        let service = ScoringService()
        // 仅有点赞
        let likesOnly = [makeSnapshot(likes: 100, comments: 0, shares: 0, views: 1000)]
        let r1 = await service.scoreEngagement(snapshots: likesOnly)
        // 仅有评论
        let commentsOnly = [makeSnapshot(likes: 0, comments: 100, shares: 0, views: 1000)]
        let r2 = await service.scoreEngagement(snapshots: commentsOnly)
        // 评论权重 > 点赞权重 → 评论得分应更高
        XCTAssertGreaterThan(r2.score, r1.score, "Comments should score higher than likes")
    }

    // MARK: - ComparisonService

    func testComparisonUpDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 200)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, .up)
        XCTAssertEqual(result.percentChange, 100.0)
    }

    func testComparisonFlatDirection() async {
        let service = ComparisonService()
        let s = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: s, previousSnapshots: s) { $0.followersCount }
        XCTAssertEqual(result.direction, .flat)
    }

    func testComparisonDownDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 80)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, .down)
    }

    // MARK: - PredictionService

    func testSMAWithSufficientData() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertEqual(results.count, 1)
        XCTAssertGreaterThan(results[0].confidence, 0)
    }

    func testSMAWithInsufficientData() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertTrue(results.isEmpty)
    }

    func testLinearRegressionProducesPrediction() async {
        let service = PredictionService()
        let data = (0..<30).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 5))
        }
        let result = await service.predictLinear(dataPoints: data, daysAhead: 7)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.predictedValue, 0)
        XCTAssertEqual(result!.method, "Linear")
    }

    func testLinearRegressionWithTooFewPoints() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let result = await service.predictLinear(dataPoints: data, daysAhead: 7)
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeSnapshot(likes: Int = 0, comments: Int = 0, shares: Int = 0, views: Int = 100, followers: Int = 100) -> Snapshot {
        Snapshot(
            accountId: 1, followersCount: followers, followingCount: 10,
            mediaCount: 5, engagementRate: 0.05,
            totalLikes: likes, totalComments: comments,
            totalShares: shares, totalViews: views,
            observedAt: Date(), createdAt: Date()
        )
    }
}
