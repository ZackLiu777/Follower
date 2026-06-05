//
//  IngestionServiceTests.swift
//  Follower

import XCTest
@testable import Follower

final class IngestionServiceTests: XCTestCase {
    func testIngestProfileAndTrend() async throws {
        let db = DatabaseManager.shared
        let eventRepo = EventRepository(db: db)
        let snapshotRepo = SnapshotRepository(db: db)
        let metricRepo = MetricRepository(db: db)
        let aggService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
        let ingestion = IngestionService(eventRepo: eventRepo, aggregationService: aggService)

        let profile = APIProfileResponse(
            username: "test", displayName: "Test",
            followersCount: 1000, followingCount: 200, mediaCount: 50,
            totalLikes: 5000, totalComments: 300, totalShares: 100,
            totalViews: 10000, engagementRate: 0.05, fetchedAt: Date()
        )
        let trend = APITrendResponse(username: "test", dataPoints: [], period: "week")

        let result = try await ingestion.ingest(accountId: 1, profile: profile, trend: trend)
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.eventsCreated, 1)
    }
}
