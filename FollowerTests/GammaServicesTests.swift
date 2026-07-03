//
//  GammaServicesTests.swift
//  FollowerTests
//
//  Gamma Premium 服务测试：Scoring, Comparison, Prediction。

import Testing
import Foundation
@testable import Follower

/// Unit tests for Gamma Premium 服务 — covers Scoring, Comparison, Prediction, Activity, Retention, Geo, AI analysis
struct GammaServicesTests {

    // MARK: - ScoringService

    /// 有效互动数据 → 评分 > 0 且 <= 100
    @MainActor
    @Test
    func testScoringWithDataReturnsValidScore() async {
        let service = ScoringService()
        let snapshots = [
            makeSnapshot(likes: 100, comments: 20, shares: 10, views: 1000),
            makeSnapshot(likes: 200, comments: 30, shares: 15, views: 2000),
        ]
        let result = await service.scoreEngagement(snapshots: snapshots)
        #expect(result.score > 0)
        #expect(result.score <= 100)
    }

    /// 空 Snapshot → 评分 0，标签 "No data"
    @MainActor
    @Test
    func testScoringEmptyReturnsZero() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [])

        #expect(result.score == 0)
        #expect(result.label == "No data")
    }

    /// comments 权重 3x vs likes 权重 1x → comments 得分应高于 likes
    @MainActor
    @Test
    func testScoringCommentsWeightedHigherThanLikes() async {
        let service = ScoringService()
        // 仅有点赞
        let likesOnly = [makeSnapshot(likes: 100, comments: 0, shares: 0, views: 1000)]
        let r1 = await service.scoreEngagement(snapshots: likesOnly)
        // 仅有评论
        let commentsOnly = [makeSnapshot(likes: 0, comments: 100, shares: 0, views: 1000)]
        let r2 = await service.scoreEngagement(snapshots: commentsOnly)
        // 评论权重 > 点赞权重 → 评论得分应更高
        #expect(r2.score > r1.score)
    }

    // MARK: - ComparisonService

    /// current > previous → 方向 UP，百分比变化 100%
    @MainActor
    @Test
    func testComparisonUpDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 200)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        #expect(result.direction == .up)
        #expect(result.percentChange == 100.0)
    }

    /// current = previous → 方向 FLAT
    @MainActor
    @Test
    func testComparisonFlatDirection() async {
        let service = ComparisonService()
        let s = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: s, previousSnapshots: s) { $0.followersCount }
        #expect(result.direction == .flat)
    }

    /// current < previous → 方向 DOWN
    @MainActor
    @Test
    func testComparisonDownDirection() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 80)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        #expect(result.direction == .down)
    }

    // MARK: - PredictionService

    /// 10 个数据点 + window=7 → 应返回 1 个有效预测结果
    @MainActor
    @Test
    func testSMAWithSufficientData() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        #expect(results.count == 1)
        #expect(results[0].confidence > 0)
    }

    /// 数据点数 < window → 返回空数组
    @MainActor
    @Test
    func testSMAWithInsufficientData() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let results = await service.predictSMA(dataPoints: data, window: 7)
        #expect(results.isEmpty)
    }

    /// 30 个线性递增数据点 → 线性回归应产生 "Linear" 方法非 nil 结果
    @MainActor
    @Test
    func testLinearRegressionProducesPrediction() async {
        let service = PredictionService()
        let data = (0..<30).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 5))
        }
        let result = await service.predictLinear(dataPoints: data, daysAhead: 7)
        #expect(result != nil)
        #expect(result!.predictedValue > 0)
        #expect(result!.method == "Linear")
    }

    /// 数据点不足 → 线性回归返回 nil
    @MainActor
    @Test
    func testLinearRegressionWithTooFewPoints() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let result = await service.predictLinear(dataPoints: data, daysAhead: 7)
        #expect(result == nil)
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
    @MainActor
    @Test
    func testActivityAnalysisCalculatesRatio() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let events = [makeEvent(accountId: 1, daysAgo: 0), makeEvent(accountId: 1, daysAgo: 1), makeEvent(accountId: 1, daysAgo: 3)]
        let result = await service.analyze(events: events, from: from, to: now)
        #expect(result.activeDays > 0)
        #expect(result.activeDaysRatio < 1.0)
    }

    /// 空事件 → activeDays = 0，标签 "Low"
    @MainActor
    @Test
    func testActivityAnalysisEmptyEvents() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let result = await service.analyze(events: [], from: Calendar.current.date(byAdding: .day, value: -7, to: now)!, to: now)
        #expect(result.activeDays == 0)
        #expect(result.label == "Low")
    }

    // MARK: - RetentionAnalysisService

    /// 粉丝递增 100→110→120 → 正增长率，非流失状态
    @MainActor
    @Test
    func testRetentionGrowingFollowers() async {
        let service = RetentionAnalysisService()
        let snapshots = [makeSnapshot(followers: 100), makeSnapshot(followers: 110), makeSnapshot(followers: 120)]
        let result = await service.analyze(snapshots: snapshots)
        #expect(result.netGrowthRate > 0)
        #expect(result.isChurning == false)
    }

    /// 粉丝连降 4 天 120→...→90 → 负增长率，处于流失状态，风险 "Low"
    @MainActor
    @Test
    func testRetentionChurnDetection() async {
        let service = RetentionAnalysisService()
        let snapshots = [makeSnapshot(followers: 120), makeSnapshot(followers: 110), makeSnapshot(followers: 100), makeSnapshot(followers: 90)]
        let result = await service.analyze(snapshots: snapshots)
        #expect(result.netGrowthRate < 0)
        #expect(result.isChurning == true)
        #expect(result.churnRiskLevel == "Low")
    }

    /// 仅 1 个 Snapshot → 风险等级 "None"（数据不足）
    @MainActor
    @Test
    func testRetentionInsufficientData() async {
        let service = RetentionAnalysisService()
        let result = await service.analyze(snapshots: [makeSnapshot(followers: 100)])
        #expect(result.churnRiskLevel == "None")
    }

    // MARK: - GeoDistributionService

    /// 调用 fetchDistribution → 返回 9 个 mock 地区，topRegion 为美国
    @MainActor
    @Test
    func testGeoDistributionReturnsMockData() async {
        let service = GeoDistributionService()
        let result = await service.fetchDistribution(accountId: 1)
        #expect(result.totalRegions == 9)
        #expect(result.topRegion?.name == "United States")
        #expect(result.topRegion?.flag == "🇺🇸")
    }

    // MARK: - AIAnalysisService

    /// 粉丝在最后 3/10 天突变 100→150 → 应检测到 anomaly
    @MainActor
    @Test
    func testAIAnomalyDetection() async {
        let service = AIAnalysisService()
        let snapshots = (0..<10).map { i in makeSnapshot(likes: 50, views: 500, followers: i < 7 ? 100 : 150) }
        let insights = await service.analyze(snapshots: snapshots)
        #expect(insights.count >= 1)
        #expect(insights.contains { $0.type == InsightType.summary })
    }

    /// 空 Snapshot → 洞察列表为空
    @MainActor
    @Test
    func testAIEmptyData() async {
        let service = AIAnalysisService()
        let insights = await service.analyze(snapshots: [])
        #expect(insights.isEmpty)
    }

    /// 粉丝从 100 骤升至 200（后 3 天）→ 应检测到 anomaly
    @MainActor
    @Test
    func testAIFollowerSurgeDetection() async {
        let service = AIAnalysisService()
        var snapshots: [Snapshot] = []
        for _ in 0..<7 { snapshots.append(makeSnapshot(followers: 100)) }
        for _ in 0..<3 { snapshots.append(makeSnapshot(followers: 200)) }
        let insights = await service.analyze(snapshots: snapshots)
        #expect(insights.contains { $0.type == InsightType.anomaly }, "Should detect follower anomaly")
    }
}
