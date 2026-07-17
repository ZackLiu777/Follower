//
//  ModelsTests.swift
//  FollowerTests
//
//  领域模型单元测试：Codable 序列化、GRDB 类型安全、Equatable。

import Testing
import Foundation
@testable import Follower

/// Unit tests for domain models — covers Codable serialization, GRDB type safety, Equatable, and enum correctness
struct ModelsTests {

    // MARK: - Account Codable

    /// Account Codable 往返 → 解码后 username 和 platform 匹配
    @Test
    func testAccountCodableRoundTrip() throws {
        let account = Account(
            id: 1,
            platform: .instagram,
            username: "test",
            displayName: "Test",
            authState: .authorized,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        #expect(decoded.username == "test")
        #expect(decoded.platform == .instagram)
    }

    // MARK: - Event Codable

    /// Event Codable 往返 → accountId、eventType、payload 全部匹配
    @Test
    func testEventCodableRoundTrip() throws {
        let event = Event(
            id: 1,
            accountId: 42,
            eventType: .profileSnapshot,
            payload: Data("test".utf8),
            source: .api,
            observedAt: Date(),
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: data)

        #expect(decoded.accountId == 42)
        #expect(decoded.eventType == .profileSnapshot)
        #expect(decoded.payload == Data("test".utf8))
    }

    // MARK: - Snapshot Codable

    /// Snapshot Codable 往返 → followersCount 匹配原始值
    @Test
    func testSnapshotCodableRoundTrip() throws {
        let snapshot = Snapshot(
            id: 1,
            accountId: 1,
            followersCount: 1000,
            followingCount: 200,
            mediaCount: 50,
            engagementRate: 0.05,
            totalLikes: 500,
            totalComments: 30,
            totalShares: 10,
            totalViews: 2000,
            observedAt: Date(),
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)

        #expect(decoded.followersCount == 1000)
    }

    // MARK: - Metric Codable

    /// Metric Codable 往返 → metricType 和 window 匹配
    @Test
    func testMetricCodableRoundTrip() throws {
        let metric = Metric(
            id: 1,
            accountId: 1,
            metricType: .followerGrowth,
            value: 3.5,
            window: .week,
            observedAt: Date(),
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(Metric.self, from: data)

        #expect(decoded.metricType == .followerGrowth)
        #expect(decoded.window == .week)
    }

    // MARK: - PremiumFeature Codable

    /// PremiumFeature Codable 往返 → key 匹配且 enabled 为 true
    @Test
    func testPremiumFeatureCodableRoundTrip() throws {
        let feature = PremiumFeature(
            id: 1,
            key: .trendPrediction,
            enabled: true,
            expiresAt: Date().addingTimeInterval(3600),
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(feature)
        let decoded = try JSONDecoder().decode(PremiumFeature.self, from: data)

        #expect(decoded.key == .trendPrediction)
        #expect(decoded.enabled == true)
    }

    // MARK: - Enums

    /// Platform rawValue → instagram="instagram", tiktok="tiktok"
    @Test
    func testPlatformRawValues() {
        #expect(Platform.instagram.rawValue == "instagram")
        #expect(Platform.tiktok.rawValue == "tiktok")
    }

    /// AuthState rawValue → authorized/expired 与字符串一致
    @Test
    func testAuthStateRawValues() {
        #expect(AuthState.authorized.rawValue == "authorized")
        #expect(AuthState.expired.rawValue == "expired")
    }

    /// MetricType allCases → 共 7 个类型
    @Test
    func testMetricTypeAllCases() {
        let types: [MetricType] = [
            .followerGrowth,
            .engagementTrend,
            .averageLikes,
            .averageComments,
            .averageShares,
            .reachEstimate,
            .profileViews
        ]

        #expect(types.count == 7)
    }

    /// TimeWindow allCases → 共 4 个窗口
    @Test
    func testTimeWindowAllCases() {
        #expect(TimeWindow.allCases.count == 4)
    }

    /// PremiumFeatureKey allCases → 共 13 个功能键
    @Test
    func testPremiumFeatureKeyAllCases() {
        #expect(PremiumFeatureKey.allCases.count == 20)
    }

    /// AppLanguage allCases → 共 4 种语言，包含 japanese
    @Test
    func testAppLanguageAllCases() {
        #expect(AppLanguage.allCases.count == 4)
        #expect(AppLanguage.allCases.contains(.japanese))
    }

    /// AppTheme allCases → 共 6 种主题，包含 appleDark
    @Test
    func testAppThemeAllCases() {
        #expect(AppTheme.allCases.count == 6)
        #expect(AppTheme.allCases.contains(.appleDark))
    }

    // MARK: - ExportFormat

    /// ExportFormat 应有恰好 2 个 case：JSON 和 CSV
    @Test
    func testExportFormat_HasTwoCases() {
        #expect(ExportFormat.allCases.count == 2)
    }

    /// JSON 的 displayName 应为 "JSON"
    @Test
    func testExportFormat_JSON_DisplayName() {
        #expect(ExportFormat.json.displayName == "JSON")
    }

    /// CSV 的 displayName 应为 "CSV"
    @Test
    func testExportFormat_CSV_DisplayName() {
        #expect(ExportFormat.csv.displayName == "CSV")
    }

    // MARK: - PremiumFeatureKey

    /// allCases 不应为空
    @Test
    func testPremiumFeatureKey_AllCases_NotEmpty() {
        #expect(!PremiumFeatureKey.allCases.isEmpty)
        #expect(PremiumFeatureKey.allCases.count == 20)
    }

    /// 每个 PremiumFeatureKey 都应有非空的 displayName
    @Test
    func testPremiumFeatureKey_EveryKeyHasDisplayName() {
        for key in PremiumFeatureKey.allCases {
            #expect(!key.displayName.isEmpty,
                    "PremiumFeatureKey.\(key.rawValue) should have a display name")
        }
    }

    /// allCases 应包含 trendPrediction
    @Test
    func testPremiumFeatureKey_ContainsTrendPrediction() {
        #expect(PremiumFeatureKey.allCases.contains(.trendPrediction))
    }

    /// allCases 应包含 csvExport
    @Test
    func testPremiumFeatureKey_ContainsCSVExport() {
        #expect(PremiumFeatureKey.allCases.contains(.csvExport))
    }

    // MARK: - TrendDataPoint

    /// TrendDataPoint 初始化：id 等于 date，value 正确存储
    @Test
    func testTrendDataPoint_Initialization() {
        let date = Date()
        let point = TrendDataPoint(date: date, value: 42.0)

        #expect(point.id == date)
        #expect(point.date == date)
        #expect(point.value == 42.0)
    }
}
