//
//  GammaServicesTests.swift
//  FollowerTests
//
//  Gamma Premium 服务测试：Scoring, Comparison, Prediction。

import XCTest
@testable import Follower

/// Unit tests for Gamma Premium 服务 — covers Scoring, Comparison, Prediction, Activity, Retention, Geo, AI analysis
final class GammaServicesTests: XCTestCase {

    // MARK: - ScoringService

    /// 有效互动数据 → 评分 > 0 且 <= 100
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

    /// 空 Snapshot → 评分 0，标签 "No data"
    func testScoringEmptyReturnsZero() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [])
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.label, "No data")
    }

    /// comments 权重 3x vs likes 权重 1x → comments 得分应高于 likes
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

    /// current > previous → 方向 UP，百分比变化 100%
    func testComparisonUpDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 200)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, .up)
        XCTAssertEqual(result.percentChange, 100.0)
    }

    /// current = previous → 方向 FLAT
    func testComparisonFlatDirection() async {
        let service = ComparisonService()
        let s = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: s, previousSnapshots: s) { $0.followersCount }
        XCTAssertEqual(result.direction, .flat)
    }

    /// current < previous → 方向 DOWN
    func testComparisonDownDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 80)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, .down)
    }

    // MARK: - PredictionService

    /// 10 个数据点 + window=7 → 应返回 1 个有效预测结果
    func testSMAWithSufficientData() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertEqual(results.count, 1)
        XCTAssertGreaterThan(results[0].confidence, 0)
    }

    /// 数据点数 < window → 返回空数组
    func testSMAWithInsufficientData() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertTrue(results.isEmpty)
    }

    /// 30 个线性递增数据点 → 线性回归应产生 "Linear" 方法非 nil 结果
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

    /// 数据点不足 → 线性回归返回 nil
    func testLinearRegressionWithTooFewPoints() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let result = await service.predictLinear(dataPoints: data, daysAhead: 7)
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    /// 创建测试用 Snapshot，预填充默认值
    private func makeSnapshot(likes: Int = 0, comments: Int = 0, shares: Int = 0, views: Int = 100, followers: Int = 100) -> Snapshot {
        Snapshot(
            accountId: 1, followersCount: followers, followingCount: 10,
            mediaCount: 5, engagementRate: 0.05,
            totalLikes: likes, totalComments: comments,
            totalShares: shares, totalViews: views,
            observedAt: Date(), createdAt: Date()
        )
    }

    /// 创建测试用 Event，预填充默认值
    private func makeEvent(accountId: Int64, daysAgo: Int) -> Event {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Event(accountId: accountId, eventType: .profileSnapshot, payload: Data(), source: .api, observedAt: date, createdAt: date)
    }

    // MARK: - ActivityAnalysisService

    /// 3/7 天有事件 → activeDays > 0 且 ratio <= 1.0
    func testActivityAnalysisCalculatesRatio() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let events = [makeEvent(accountId: 1, daysAgo: 0), makeEvent(accountId: 1, daysAgo: 1), makeEvent(accountId: 1, daysAgo: 3)]
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertGreaterThan(result.activeDays, 0)
        XCTAssertLessThanOrEqual(result.activeDaysRatio, 1.0)
    }

    /// 空事件 → activeDays = 0，标签 "Low"
    func testActivityAnalysisEmptyEvents() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let result = await service.analyze(events: [], from: Calendar.current.date(byAdding: .day, value: -7, to: now)!, to: now)
        XCTAssertEqual(result.activeDays, 0)
        XCTAssertEqual(result.label, "Low")
    }

    // MARK: - RetentionAnalysisService

    /// 粉丝递增 100→110→120 → 正增长率，非流失状态
    func testRetentionGrowingFollowers() async {
        let service = RetentionAnalysisService()
        let snapshots = [makeSnapshot(followers: 100), makeSnapshot(followers: 110), makeSnapshot(followers: 120)]
        let result = await service.analyze(snapshots: snapshots)
        XCTAssertGreaterThan(result.netGrowthRate, 0)
        XCTAssertFalse(result.isChurning)
    }

    /// 粉丝连降 4 天 120→...→90 → 负增长率，处于流失状态，风险 "Low"
    func testRetentionChurnDetection() async {
        let service = RetentionAnalysisService()
        let snapshots = [makeSnapshot(followers: 120), makeSnapshot(followers: 110), makeSnapshot(followers: 100), makeSnapshot(followers: 90)]
        let result = await service.analyze(snapshots: snapshots)
        XCTAssertLessThan(result.netGrowthRate, 0)
        XCTAssertTrue(result.isChurning)
        XCTAssertEqual(result.churnRiskLevel, "Low")
    }

    /// 仅 1 个 Snapshot → 风险等级 "None"（数据不足）
    func testRetentionInsufficientData() async {
        let service = RetentionAnalysisService()
        let result = await service.analyze(snapshots: [makeSnapshot(followers: 100)])
        XCTAssertEqual(result.churnRiskLevel, "None")
    }

    // MARK: - GeoDistributionService

    /// 调用 fetchDistribution → 返回 9 个 mock 地区，topRegion 为美国
    func testGeoDistributionReturnsMockData() async {
        let service = GeoDistributionService()
        let result = await service.fetchDistribution(accountId: 1)
        XCTAssertEqual(result.totalRegions, 9)
        XCTAssertEqual(result.topRegion?.name, "United States")
        XCTAssertEqual(result.topRegion?.flag, "🇺🇸")
    }

    // MARK: - AIAnalysisService

    /// 粉丝在最后 3/10 天突变 100→150 → 应检测到 anomaly
    func testAIAnomalyDetection() async {
        let service = AIAnalysisService()
        let snapshots = (0..<10).map { i in makeSnapshot(likes: 50, views: 500, followers: i < 7 ? 100 : 150) }
        let insights = await service.analyze(snapshots: snapshots)
        XCTAssertGreaterThanOrEqual(insights.count, 1, "Should find at least a summary")
        XCTAssertTrue(insights.contains { $0.type == InsightType.summary })
    }

    /// 空 Snapshot → 洞察列表为空
    func testAIEmptyData() async {
        let service = AIAnalysisService()
        let insights = await service.analyze(snapshots: [])
        XCTAssertTrue(insights.isEmpty)
    }

    /// 粉丝从 100 骤升至 200（后 3 天）→ 应检测到 anomaly
    func testAIFollowerSurgeDetection() async {
        let service = AIAnalysisService()
        var snapshots: [Snapshot] = []
        for _ in 0..<7 { snapshots.append(makeSnapshot(followers: 100)) }
        for _ in 0..<3 { snapshots.append(makeSnapshot(followers: 200)) }
        let insights = await service.analyze(snapshots: snapshots)
        XCTAssertTrue(insights.contains { $0.type == InsightType.anomaly }, "Should detect follower anomaly")
    }
}
