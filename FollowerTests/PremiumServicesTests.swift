//
//  PremiumServicesTests.swift
//  FollowerTests
//
//  Premium 全服务单元测试：Prediction, Scoring, Retention, Activity,
//  Comparison, GeoDistribution, AIAnalysis。
//

import XCTest
@testable import Follower

/// Unit tests for Premium 全服务 — covers Prediction, Scoring, Retention, Activity, Comparison, GeoDistribution, AIAnalysis
final class PremiumServicesTests: XCTestCase {

    // MARK: - PredictionService

    /// SMA 窗口=7，30 个递增数据点 → 应返回 1 个预测结果且置信度 > 0
    func testPredictSMA_WithValidData_ReturnsResults() async {
        let service = PredictionService()
        let data = (0..<30).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertEqual(results.count, 1)
        XCTAssertGreaterThan(results[0].predictedValue, 0)
        XCTAssertGreaterThan(results[0].confidence, 0)
        XCTAssertEqual(results[0].method, "SMA7")
    }

    /// 空数据 → 返回空数组
    func testPredictSMA_WithEmptyData_ReturnsEmpty() async {
        let service = PredictionService()
        let results = await service.predictSMA(dataPoints: [], window: 7)
        XCTAssertTrue(results.isEmpty)
    }

    /// 单个数据点，窗口=1 → 仍可工作（count >= window）
    func testPredictSMA_WithSingleDataPoint_StillWorks() async {
        let service = PredictionService()
        let data = [(Date(), 100.0)]
        let results = await service.predictSMA(dataPoints: data, window: 1)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].predictedValue, 100.0)
    }

    /// 全零序列 → 预测值应为 0
    func testPredictSMA_AllZeros_ReturnsZeros() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), 0.0)
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].predictedValue, 0.0)
    }

    /// 窗口 > 数据量 → 返回空数组（降级处理）
    func testPredictSMA_WindowLargerThanData_FallsBack() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        let results = await service.predictSMA(dataPoints: data, window: 10)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - ScoringService

    /// 正常 Snapshot 序列 → 应返回有效分数 0-100
    func testScoreEngagement_NormalSnapshot_ReturnsScore() async {
        let service = ScoringService()
        let snapshots = [
            makeSnapshot(followers: 100, likes: 50, comments: 10, shares: 5, views: 500),
            makeSnapshot(followers: 100, likes: 60, comments: 12, shares: 6, views: 600),
        ]
        let result = await service.scoreEngagement(snapshots: snapshots)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 100)
        XCTAssertGreaterThan(result.engagementRate, 0)
    }

    /// 全部为零 → 分数应为 0
    func testScoreEngagement_AllZeros_ReturnsZero() async {
        let service = ScoringService()
        let snapshots = [makeSnapshot(followers: 100, likes: 0, comments: 0, shares: 0, views: 0)]
        let result = await service.scoreEngagement(snapshots: snapshots)
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.label, "Low")
    }

    /// shares 权重最高（5x）→ high shares 应显著提升分数（使用低值避免触碰 100 上限）
    func testScoreEngagement_HighShares_BoostsScore() async {
        let service = ScoringService()
        // 只有 likes — 5 likes / 100 views * 100 = 5 分
        let likesOnly = [makeSnapshot(followers: 100, likes: 5, comments: 0, shares: 0, views: 100)]
        let r1 = await service.scoreEngagement(snapshots: likesOnly)
        // 只有 shares（同样数量但权重 5x）— 5*5/100*100 = 25 分
        let sharesOnly = [makeSnapshot(followers: 100, likes: 0, comments: 0, shares: 5, views: 100)]
        let r2 = await service.scoreEngagement(snapshots: sharesOnly)
        // shares 权重 5x vs likes 权重 1x → r2 = 5x r1
        XCTAssertGreaterThan(r2.score, r1.score * 4.0)
    }

    /// 单个 Snapshot → 正常工作
    func testScoreEngagement_SingleSnapshot_Works() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 80, views: 100)])
        XCTAssertEqual(result.score, 80.0)
        XCTAssertEqual(result.likesWeight, 1.0)
        XCTAssertEqual(result.commentsWeight, 3.0)
        XCTAssertEqual(result.sharesWeight, 5.0)
    }

    /// 高分 → Excellent 标签（>=80）
    func testQualityLabel_Excellent_Above90() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 90, views: 100)])
        XCTAssertEqual(result.label, "Excellent")
    }

    /// 中等偏上 → Great 标签（60-80）
    func testQualityLabel_Great_Above70() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 70, views: 100)])
        XCTAssertEqual(result.label, "Great")
    }

    /// 中等 → Good 标签（40-60）
    func testQualityLabel_Good_Above50() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 50, views: 100)])
        XCTAssertEqual(result.label, "Good")
    }

    /// 中等偏下 → Fair 标签（20-40）
    func testQualityLabel_Fair_Above30() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 30, views: 100)])
        XCTAssertEqual(result.label, "Fair")
    }

    /// 低分 → Low 标签（<20）
    func testQualityLabel_Low_Below30() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(snapshots: [makeSnapshot(followers: 100, likes: 10, views: 100)])
        XCTAssertEqual(result.label, "Low")
    }

    // MARK: - RetentionAnalysisService

    /// 连续增长的粉丝序列 → 正增长率
    func testAnalyze_GrowingFollowers_PositiveGrowthRate() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 100),
            makeSnapshot(followers: 120),
            makeSnapshot(followers: 150),
        ]
        let result = await service.analyze(snapshots: snapshots)
        XCTAssertGreaterThan(result.netGrowthRate, 0)
        XCTAssertFalse(result.isChurning)
    }

    /// 连续下降的粉丝序列 → 负增长率且处于流失状态
    func testAnalyze_DecliningFollowers_NegativeGrowthRate() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 150),
            makeSnapshot(followers: 130),
            makeSnapshot(followers: 110),
            makeSnapshot(followers: 100),
        ]
        let result = await service.analyze(snapshots: snapshots)
        XCTAssertLessThan(result.netGrowthRate, 0)
        XCTAssertTrue(result.isChurning)
    }

    /// 空 Snapshot 序列 → 安全降级，返回默认值
    func testAnalyze_EmptySnapshots_HandlesGracefully() async {
        let service = RetentionAnalysisService()
        let result = await service.analyze(snapshots: [])
        XCTAssertEqual(result.netGrowthRate, 0)
        XCTAssertEqual(result.churnRiskLevel, "None")
        XCTAssertEqual(result.startFollowers, 0)
        XCTAssertEqual(result.endFollowers, 0)
    }

    /// 0 天连续下降 → 风险等级 "None"
    func testChurnRisk_ZeroDays_None() {
        let service = RetentionAnalysisService()
        XCTAssertEqual(service.churnRisk(consecutiveNegativeDays: 0), "None")
    }

    /// 2 天连续下降 → 风险等级 "Low"
    func testChurnRisk_TwoDays_Low() {
        let service = RetentionAnalysisService()
        XCTAssertEqual(service.churnRisk(consecutiveNegativeDays: 2), "Low")
    }

    /// 5 天连续下降 → 风险等级 "Medium"
    func testChurnRisk_FiveDays_Medium() {
        let service = RetentionAnalysisService()
        XCTAssertEqual(service.churnRisk(consecutiveNegativeDays: 5), "Medium")
    }

    /// 10 天连续下降 → 风险等级 "High"
    func testChurnRisk_TenDays_High() {
        let service = RetentionAnalysisService()
        XCTAssertEqual(service.churnRisk(consecutiveNegativeDays: 10), "High")
    }

    /// 起始和结束粉丝数应正确记录
    func testAnalyze_StartEndFollowers_CalculatedCorrectly() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 200),
            makeSnapshot(followers: 250),
            makeSnapshot(followers: 300),
        ]
        let result = await service.analyze(snapshots: snapshots)
        XCTAssertEqual(result.startFollowers, 200)
        XCTAssertEqual(result.endFollowers, 300)
    }

    // MARK: - ActivityAnalysisService

    /// 每天都有事件 → 高活跃天数比例
    func testAnalyze_DailyEvents_ReturnsHighActiveDaysRatio() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        var events: [Event] = []
        for i in 0..<7 {
            events.append(makeEvent(accountId: 1, daysAgo: i))
        }
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertEqual(result.activeDaysRatio, 1.0)
        XCTAssertEqual(result.activeDays, 7)
        XCTAssertEqual(result.label, "Highly Active")
    }

    /// 无事件 → 活跃天数比例为 0
    func testAnalyze_NoEvents_ReturnsZeroRatio() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let result = await service.analyze(events: [], from: from, to: now)
        XCTAssertEqual(result.activeDaysRatio, 0)
        XCTAssertEqual(result.activeDays, 0)
        XCTAssertEqual(result.label, "Low")
    }

    /// 所有事件集中在同一星期几 → mostActiveDay 应正确识别
    func testAnalyze_MostActiveDay_Correct() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -14, to: now)!
        // 找到最近的星期一
        let cal = Calendar.current
        var monday = now
        while cal.component(.weekday, from: monday) != 2 { // 2=Monday
            monday = cal.date(byAdding: .day, value: -1, to: monday)!
        }
        let events = [Event(accountId: 1, eventType: .profileSnapshot, payload: Data(), source: .api, observedAt: monday, createdAt: monday)]
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertEqual(result.mostActiveDay, 2) // Monday = 2
    }

    /// 高活跃度标签 "Highly Active"
    func testActivityLabel_HighlyActive() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        // 6/7 天活跃 → 0.857 → "Highly Active"
        var events: [Event] = []
        for i in 0..<6 {
            events.append(makeEvent(accountId: 1, daysAgo: i))
        }
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertEqual(result.label, "Highly Active")
    }

    /// 中等活跃度标签 "Moderate"
    func testActivityLabel_Moderate() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        // 2/7 天活跃 → 0.286 → "Moderate"
        var events: [Event] = []
        for i in [0, 3] {
            events.append(makeEvent(accountId: 1, daysAgo: i))
        }
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertEqual(result.label, "Moderate")
    }

    /// 低活跃度标签 "Low"
    func testActivityLabel_Low() async {
        let service = ActivityAnalysisService()
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        // 1/7 天活跃 → 0.143 → "Low"
        let events = [makeEvent(accountId: 1, daysAgo: 0)]
        let result = await service.analyze(events: events, from: from, to: now)
        XCTAssertEqual(result.label, "Low")
    }

    // MARK: - ComparisonService

    /// 当前 > 前一期 → 方向 UP
    func testCompare_Growing_Up() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 200)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, ComparisonDirection.up)
        XCTAssertEqual(result.percentChange, 100.0)
    }

    /// 当前 < 前一期 → 方向 DOWN
    func testCompare_Declining_Down() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 80)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, ComparisonDirection.down)
        XCTAssertEqual(result.percentChange, -20.0)
    }

    /// 变化 < 0.5% → 方向 FLAT
    func testCompare_Flat_WithinThreshold() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 1000)]
        let previous = [makeSnapshot(followers: 1001)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.direction, ComparisonDirection.flat)
    }

    /// 前一周期为空 → 优雅处理，当前均值为实际值
    func testCompare_WithEmptyPrevious_HandlesGracefully() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 200)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: []) { $0.followersCount }
        XCTAssertEqual(result.currentAvg, 200.0)
        XCTAssertEqual(result.previousAvg, 0.0)
        XCTAssertEqual(result.percentChange, 0.0)
    }

    /// 百分比变化应精确计算
    func testCompare_PercentChange_CalculatedCorrectly() async {
        let service = ComparisonService()
        let current = [makeSnapshot(followers: 150)]
        let previous = [makeSnapshot(followers: 100)]
        let result = await service.compare(currentSnapshots: current, previousSnapshots: previous) { $0.followersCount }
        XCTAssertEqual(result.percentChange, 50.0)
        XCTAssertEqual(result.absoluteChange, 50.0)
    }

    // MARK: - GeoDistributionService

    /// Mock 数据应返回 9 个地区
    func testFetchDistribution_ReturnsMockRegions() async {
        let service = GeoDistributionService()
        let result = await service.fetchDistribution(accountId: 1)
        XCTAssertEqual(result.totalRegions, 9)
        XCTAssertEqual(result.regions.count, 9)
    }

    /// topRegion 应为美国
    func testFetchDistribution_HasTopRegion() async {
        let service = GeoDistributionService()
        let result = await service.fetchDistribution(accountId: 1)
        XCTAssertNotNil(result.topRegion)
        XCTAssertEqual(result.topRegion?.name, "United States")
        XCTAssertEqual(result.topRegion?.flag, "🇺🇸")
    }

    /// 地区列表不应为空
    func testFetchDistribution_RegionsNotEmpty() async {
        let service = GeoDistributionService()
        let result = await service.fetchDistribution(accountId: 42)
        XCTAssertFalse(result.regions.isEmpty)
        // 所有地区应有名称和国旗
        for region in result.regions {
            XCTAssertFalse(region.name.isEmpty)
            XCTAssertFalse(region.flag.isEmpty)
        }
    }

    // MARK: - AIAnalysisService

    /// 增长趋势 → 应返回包含 summary 的洞察
    func testAnalyze_GrowingTrend_ReturnsInsights() async {
        let service = AIAnalysisService()
        let snapshots = (0..<10).map { i in
            makeSnapshot(followers: 100 + i * 5, likes: 50, views: 500)
        }
        let insights = await service.analyze(snapshots: snapshots)
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains { $0.type == InsightType.summary })
    }

    /// 粉丝急剧下降 → 应检测到 anomaly
    func testAnalyze_DecliningTrend_DetectsAnomaly() async {
        let service = AIAnalysisService()
        var snapshots: [Snapshot] = []
        // 前 7 天稳定 200 粉丝
        for _ in 0..<7 {
            snapshots.append(makeSnapshot(followers: 200, likes: 50, views: 500))
        }
        // 后 3 天跌至 100 粉丝（下降 50%，触发异常检测）
        for _ in 0..<3 {
            snapshots.append(makeSnapshot(followers: 100, likes: 50, views: 500))
        }
        let insights = await service.analyze(snapshots: snapshots)
        XCTAssertTrue(insights.contains { $0.type == InsightType.anomaly }, "Should detect follower anomaly on sharp decline")
    }

    /// 稳定趋势 → 至少返回 summary 洞察
    func testAnalyze_StableTrend_ReturnsSummary() async {
        let service = AIAnalysisService()
        let snapshots = (0..<10).map { _ in
            makeSnapshot(followers: 100, likes: 30, views: 300)
        }
        let insights = await service.analyze(snapshots: snapshots)
        XCTAssertTrue(insights.contains { $0.type == InsightType.summary })
        let summary = insights.first { $0.type == InsightType.summary }
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.severity, InsightSeverity.info)
    }

    /// 空 Snapshot → 返回空洞察列表
    func testAnalyze_EmptySnapshots_ReturnsEmpty() async {
        let service = AIAnalysisService()
        let insights = await service.analyze(snapshots: [])
        XCTAssertTrue(insights.isEmpty)
    }

    // MARK: - Helpers

    /// 创建测试用 Snapshot，预填充默认值
    private func makeSnapshot(
        followers: Int = 100,
        likes: Int = 0,
        comments: Int = 0,
        shares: Int = 0,
        views: Int = 100
    ) -> Snapshot {
        Snapshot(
            accountId: 1,
            followersCount: followers,
            followingCount: 10,
            mediaCount: 5,
            engagementRate: views > 0 ? Double(likes + comments + shares) / Double(views) : 0,
            totalLikes: likes,
            totalComments: comments,
            totalShares: shares,
            totalViews: views,
            observedAt: Date(),
            createdAt: Date()
        )
    }

    /// 创建测试用 Event，预填充默认值
    private func makeEvent(accountId: Int64, daysAgo: Int) -> Event {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Event(
            accountId: accountId,
            eventType: .profileSnapshot,
            payload: Data(),
            source: .api,
            observedAt: date,
            createdAt: date
        )
    }
}
