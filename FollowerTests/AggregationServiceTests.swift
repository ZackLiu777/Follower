//
//  AggregationServiceTests.swift
//  Follower

import XCTest
@testable import Follower

final class AggregationServiceTests: XCTestCase {
    func testEmptyAggregation() async throws {
        let db = DatabaseManager.shared
        let eventRepo = EventRepository(db: db)
        let snapshotRepo = SnapshotRepository(db: db)
        let metricRepo = MetricRepository(db: db)
        let service = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)

        let result = try await service.aggregate(accountId: 999, from: Date.distantPast, to: Date())
        XCTAssertEqual(result.snapshotsUpdated, 0)
        XCTAssertEqual(result.metricsUpdated, 0)
    }
}
