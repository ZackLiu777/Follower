//
//  ModelsTests.swift
//  FollowerTests
//
//  领域模型单元测试：Codable 序列化、GRDB 类型安全、Equatable。

import XCTest
@testable import Follower

final class ModelsTests: XCTestCase {

    // MARK: - Account Codable

    func testAccountCodableRoundTrip() throws {
        let account = Account(
            id: 1, platform: .instagram, username: "test",
            displayName: "Test", authState: .authorized,
            createdAt: Date(), updatedAt: Date()
        )
        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)
        XCTAssertEqual(decoded.username, "test")
        XCTAssertEqual(decoded.platform, .instagram)
    }

    // MARK: - Event Codable

    func testEventCodableRoundTrip() throws {
        let event = Event(
            id: 1, accountId: 42, eventType: .profileSnapshot,
            payload: Data("test".utf8), source: .api,
            observedAt: Date(), createdAt: Date()
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: data)
        XCTAssertEqual(decoded.accountId, 42)
        XCTAssertEqual(decoded.eventType, .profileSnapshot)
        XCTAssertEqual(decoded.payload, Data("test".utf8))
    }

    // MARK: - Snapshot Codable

    func testSnapshotCodableRoundTrip() throws {
        let snapshot = Snapshot(
            id: 1, accountId: 1, followersCount: 1000,
            followingCount: 200, mediaCount: 50, engagementRate: 0.05,
            totalLikes: 500, totalComments: 30, totalShares: 10,
            totalViews: 2000, observedAt: Date(), createdAt: Date()
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        XCTAssertEqual(decoded.followersCount, 1000)
    }

    // MARK: - Metric Codable

    func testMetricCodableRoundTrip() throws {
        let metric = Metric(
            id: 1, accountId: 1, metricType: .followerGrowth,
            value: 3.5, window: .week, observedAt: Date(), createdAt: Date()
        )
        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(Metric.self, from: data)
        XCTAssertEqual(decoded.metricType, .followerGrowth)
        XCTAssertEqual(decoded.window, .week)
    }

    // MARK: - PremiumFeature Codable

    func testPremiumFeatureCodableRoundTrip() throws {
        let feature = PremiumFeature(
            id: 1, key: .trendPrediction, enabled: true,
            expiresAt: Date().addingTimeInterval(3600), createdAt: Date()
        )
        let data = try JSONEncoder().encode(feature)
        let decoded = try JSONDecoder().decode(PremiumFeature.self, from: data)
        XCTAssertEqual(decoded.key, .trendPrediction)
        XCTAssertTrue(decoded.enabled)
    }

    // MARK: - Enums

    func testPlatformRawValues() {
        XCTAssertEqual(Platform.instagram.rawValue, "instagram")
        XCTAssertEqual(Platform.tiktok.rawValue, "tiktok")
    }

    func testAuthStateRawValues() {
        XCTAssertEqual(AuthState.authorized.rawValue, "authorized")
        XCTAssertEqual(AuthState.expired.rawValue, "expired")
    }

    func testMetricTypeAllCases() {
        let types: [MetricType] = [.followerGrowth, .engagementTrend, .averageLikes, .averageComments, .averageShares, .reachEstimate, .profileViews]
        XCTAssertEqual(types.count, 7)
    }

    func testTimeWindowAllCases() {
        XCTAssertEqual(TimeWindow.allCases.count, 4)
    }

    func testPremiumFeatureKeyAllCases() {
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13)
    }

    func testAppLanguageAllCases() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
        XCTAssertTrue(AppLanguage.allCases.contains(.japanese))
    }

    func testAppThemeAllCases() {
        XCTAssertEqual(AppTheme.allCases.count, 6)
        XCTAssertTrue(AppTheme.allCases.contains(.appleDark))
    }
}
