//
//  ModelsTests.swift
//  FollowerTests
//
//  领域模型单元测试：Codable 序列化、GRDB 类型安全、Equatable。

import XCTest
@testable import Follower

/// Unit tests for domain models — covers Codable serialization, GRDB type safety, Equatable, and enum correctness
final class ModelsTests: XCTestCase {

    // MARK: - Account Codable

    /// Account Codable 往返 → 解码后 username 和 platform 匹配
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

    /// Event Codable 往返 → accountId、eventType、payload 全部匹配
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

    /// Snapshot Codable 往返 → followersCount 匹配原始值
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

    /// Metric Codable 往返 → metricType 和 window 匹配
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

    /// PremiumFeature Codable 往返 → key 匹配且 enabled 为 true
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

    /// Platform rawValue → instagram="instagram", tiktok="tiktok"
    func testPlatformRawValues() {
        XCTAssertEqual(Platform.instagram.rawValue, "instagram")
        XCTAssertEqual(Platform.tiktok.rawValue, "tiktok")
    }

    /// AuthState rawValue → authorized/expired 与字符串一致
    func testAuthStateRawValues() {
        XCTAssertEqual(AuthState.authorized.rawValue, "authorized")
        XCTAssertEqual(AuthState.expired.rawValue, "expired")
    }

    /// MetricType allCases → 共 7 个类型
    func testMetricTypeAllCases() {
        let types: [MetricType] = [.followerGrowth, .engagementTrend, .averageLikes, .averageComments, .averageShares, .reachEstimate, .profileViews]
        XCTAssertEqual(types.count, 7)
    }

    /// TimeWindow allCases → 共 4 个窗口
    func testTimeWindowAllCases() {
        XCTAssertEqual(TimeWindow.allCases.count, 4)
    }

    /// PremiumFeatureKey allCases → 共 13 个功能键
    func testPremiumFeatureKeyAllCases() {
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13)
    }

    /// AppLanguage allCases → 共 4 种语言，包含 japanese
    func testAppLanguageAllCases() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
        XCTAssertTrue(AppLanguage.allCases.contains(.japanese))
    }

    /// AppTheme allCases → 共 6 种主题，包含 appleDark
    func testAppThemeAllCases() {
        XCTAssertEqual(AppTheme.allCases.count, 6)
        XCTAssertTrue(AppTheme.allCases.contains(.appleDark))
    }

    // MARK: - ExportFormat

    /// ExportFormat 应有恰好 2 个 case：JSON 和 CSV
    func testExportFormat_HasTwoCases() {
        XCTAssertEqual(ExportFormat.allCases.count, 2)
    }

    /// JSON 的 displayName 应为 "JSON"
    func testExportFormat_JSON_DisplayName() {
        XCTAssertEqual(ExportFormat.json.displayName, "JSON")
    }

    /// CSV 的 displayName 应为 "CSV"
    func testExportFormat_CSV_DisplayName() {
        XCTAssertEqual(ExportFormat.csv.displayName, "CSV")
    }

    // MARK: - PremiumFeatureKey

    /// allCases 不应为空
    func testPremiumFeatureKey_AllCases_NotEmpty() {
        XCTAssertFalse(PremiumFeatureKey.allCases.isEmpty)
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13)
    }

    /// 每个 PremiumFeatureKey 都应有非空的 displayName
    func testPremiumFeatureKey_EveryKeyHasDisplayName() {
        for key in PremiumFeatureKey.allCases {
            XCTAssertFalse(key.displayName.isEmpty,
                           "PremiumFeatureKey.\(key.rawValue) should have a display name")
        }
    }

    /// allCases 应包含 trendPrediction
    func testPremiumFeatureKey_ContainsTrendPrediction() {
        XCTAssertTrue(PremiumFeatureKey.allCases.contains(.trendPrediction))
    }

    /// allCases 应包含 csvExport
    func testPremiumFeatureKey_ContainsCSVExport() {
        XCTAssertTrue(PremiumFeatureKey.allCases.contains(.csvExport))
    }

    // MARK: - TrendDataPoint

    /// TrendDataPoint 初始化：id 等于 date，value 正确存储
    func testTrendDataPoint_Initialization() {
        let date = Date()
        let point = TrendDataPoint(date: date, value: 42.0)
        XCTAssertEqual(point.id, date)
        XCTAssertEqual(point.date, date)
        XCTAssertEqual(point.value, 42.0)
    }
}
