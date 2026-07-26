//
//  PremiumServicesTests.swift
//  FollowerTests
//
//  Premium 全服务单元测试：Prediction, Scoring, Retention, Activity,
//  Comparison, GeoDistribution, AIAnalysis。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for Premium 全服务 — covers Prediction, Scoring, Retention, Activity, Comparison, GeoDistribution, AIAnalysis
struct PremiumServicesTests {

    // MARK: - PredictionService

    /// SMA 窗口=7，30 个递增数据点 → 应返回 1 个预测结果且置信度 > 0
    @MainActor
    @Test
    func testPredictSMA_WithValidData_ReturnsResults() async {
        let service = PredictionService()
        let data = (0..<30).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }

        let results = await service.predictSMA(dataPoints: data, window: 7)

        #expect(results.count == 1)
        #expect(results[0].predictedValue > 0)
        #expect(results[0].confidence > 0)
        #expect(results[0].method == "SMA7")
    }

    /// 空数据 → 返回空数组
    @MainActor
    @Test
    func testPredictSMA_WithEmptyData_ReturnsEmpty() async {
        let service = PredictionService()
        let results = await service.predictSMA(dataPoints: [], window: 7)
        #expect(results.isEmpty)
    }

    /// 单个数据点，窗口=1 → 仍可工作（count >= window）
    @MainActor
    @Test
    func testPredictSMA_WithSingleDataPoint_StillWorks() async {
        let service = PredictionService()
        let data = [(Date(), 100.0)]

        let results = await service.predictSMA(dataPoints: data, window: 1)

        #expect(results.count == 1)
        #expect(results[0].predictedValue == 100.0)
    }

    /// 全零序列 → 预测值应为 0
    @MainActor
    @Test
    func testPredictSMA_AllZeros_ReturnsZeros() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), 0.0)
        }

        let results = await service.predictSMA(dataPoints: data, window: 7)

        #expect(results.count == 1)
        #expect(results[0].predictedValue == 0.0)
    }

    /// 窗口 > 数据量 → 返回空数组（降级处理）
    @MainActor
    @Test
    func testPredictSMA_WindowLargerThanData_FallsBack() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]

        let results = await service.predictSMA(dataPoints: data, window: 10)

        #expect(results.isEmpty)
    }

    // MARK: - ScoringService

    /// 正常 Snapshot 序列 → 应返回有效分数 0-100
    @MainActor
    @Test
    func testScoreEngagement_NormalSnapshot_ReturnsScore() async {
        let service = ScoringService()
        let snapshots = [
            makeSnapshot(followers: 100, likes: 50, comments: 10, shares: 5, views: 500),
            makeSnapshot(followers: 100, likes: 60, comments: 12, shares: 6, views: 600),
        ]

        let result = await service.scoreEngagement(snapshots: snapshots)

        #expect(result.score > 0)
        #expect(result.score <= 100)
        #expect(result.engagementRate > 0)
    }

    /// 全部为零 → 分数应为 0
    @MainActor
    @Test
    func testScoreEngagement_AllZeros_ReturnsZero() async {
        let service = ScoringService()
        let snapshots = [makeSnapshot(followers: 100, likes: 0, comments: 0, shares: 0, views: 0)]

        let result = await service.scoreEngagement(snapshots: snapshots)

        #expect(result.score == 0)
        #expect(result.label == "Low")
    }

    /// shares 权重最高（5x）→ high shares 应显著提升分数（使用低值避免触碰 100 上限）
    @MainActor
    @Test
    func testScoreEngagement_HighShares_BoostsScore() async {
        let service = ScoringService()

        let likesOnly = [makeSnapshot(followers: 100, likes: 5, comments: 0, shares: 0, views: 100)]
        let r1 = await service.scoreEngagement(snapshots: likesOnly)

        let sharesOnly = [makeSnapshot(followers: 100, likes: 0, comments: 0, shares: 5, views: 100)]
        let r2 = await service.scoreEngagement(snapshots: sharesOnly)

        #expect(r2.score > r1.score * 4.0)
    }

    /// 单个 Snapshot → 正常工作
    @MainActor
    @Test
    func testScoreEngagement_SingleSnapshot_Works() async {
        let service = ScoringService()

        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 80, views: 100)]
        )

        #expect(result.score == 80.0)
        #expect(result.likesWeight == 1.0)
        #expect(result.commentsWeight == 3.0)
        #expect(result.sharesWeight == 5.0)
    }

    /// 高分 → Excellent 标签（>=80）
    @MainActor
    @Test
    func testQualityLabel_Excellent_Above90() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 90, views: 100)]
        )
        #expect(result.label == "Excellent")
    }

    /// 中等偏上 → Great 标签（60-80）
    @MainActor
    @Test
    func testQualityLabel_Great_Above70() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 70, views: 100)]
        )
        #expect(result.label == "Great")
    }

    /// 中等 → Good 标签（40-60）
    @MainActor
    @Test
    func testQualityLabel_Good_Above50() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 50, views: 100)]
        )
        #expect(result.label == "Good")
    }

    /// 中等偏下 → Fair 标签（20-40）
    @MainActor
    @Test
    func testQualityLabel_Fair_Above30() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 30, views: 100)]
        )
        #expect(result.label == "Fair")
    }

    /// 低分 → Low 标签（<20）
    @MainActor
    @Test
    func testQualityLabel_Low_Below30() async {
        let service = ScoringService()
        let result = await service.scoreEngagement(
            snapshots: [makeSnapshot(followers: 100, likes: 10, views: 100)]
        )
        #expect(result.label == "Low")
    }

    // MARK: - RetentionAnalysisService

    /// 连续增长的粉丝序列 → 正增长率
    @MainActor
    @Test
    func testAnalyze_GrowingFollowers_PositiveGrowthRate() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 100),
            makeSnapshot(followers: 120),
            makeSnapshot(followers: 150),
        ]

        let result = await service.analyze(snapshots: snapshots)

        #expect(result.netGrowthRate > 0)
        #expect(result.isChurning == false)
    }

    /// 连续下降的粉丝序列 → 负增长率且处于流失状态
    @MainActor
    @Test
    func testAnalyze_DecliningFollowers_NegativeGrowthRate() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 150),
            makeSnapshot(followers: 130),
            makeSnapshot(followers: 110),
            makeSnapshot(followers: 100),
        ]

        let result = await service.analyze(snapshots: snapshots)

        #expect(result.netGrowthRate < 0)
        #expect(result.isChurning == true)
    }

    /// 空 Snapshot 序列 → 安全降级，返回默认值
    @MainActor
    @Test
    func testAnalyze_EmptySnapshots_HandlesGracefully() async {
        let service = RetentionAnalysisService()

        let result = await service.analyze(snapshots: [])

        #expect(result.netGrowthRate == 0)
        #expect(result.churnRiskLevel == "None")
        #expect(result.startFollowers == 0)
        #expect(result.endFollowers == 0)
    }

    /// 0 天连续下降 → 风险等级 "None"
    @Test
    func testChurnRisk_ZeroDays_None() {
        let service = RetentionAnalysisService()
        #expect(service.churnRisk(consecutiveNegativeDays: 0) == "None")
    }

    /// 2 天连续下降 → 风险等级 "Low"
    @Test
    func testChurnRisk_TwoDays_Low() {
        let service = RetentionAnalysisService()
        #expect(service.churnRisk(consecutiveNegativeDays: 2) == "Low")
    }

    /// 5 天连续下降 → 风险等级 "Medium"
    @Test
    func testChurnRisk_FiveDays_Medium() {
        let service = RetentionAnalysisService()
        #expect(service.churnRisk(consecutiveNegativeDays: 5) == "Medium")
    }

    /// 10 天连续下降 → 风险等级 "High"
    @Test
    func testChurnRisk_TenDays_High() {
        let service = RetentionAnalysisService()
        #expect(service.churnRisk(consecutiveNegativeDays: 10) == "High")
    }

    /// 起始和结束粉丝数应正确记录
    @MainActor
    @Test
    func testAnalyze_StartEndFollowers_CalculatedCorrectly() async {
        let service = RetentionAnalysisService()
        let snapshots = [
            makeSnapshot(followers: 200),
            makeSnapshot(followers: 250),
            makeSnapshot(followers: 300),
        ]

        let result = await service.analyze(snapshots: snapshots)

        #expect(result.startFollowers == 200)
        #expect(result.endFollowers == 300)
    }

    // MARK: - ActivityAnalysisService

    /// 每天都有事件 → 高活跃天数比例
    @MainActor
    @Test
    func testAnalyze_DailyEvents_ReturnsHighActiveDaysRatio() async {
        let service = ActivityAnalysisService()

        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let events: [Event] = (0..<7).map {
            makeEvent(accountId: 1, daysAgo: $0)
        }

        let result = await service.analyze(events: events, from: from, to: now)

        #expect(result.activeDaysRatio == 1.0)
        #expect(result.activeDays == 7)
        #expect(result.label == "Highly Active")
    }

    /// 无事件 → 活跃天数比例为 0
    @MainActor
    @Test
    func testAnalyze_NoEvents_ReturnsZeroRatio() async {
        let service = ActivityAnalysisService()

        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let result = await service.analyze(events: [], from: from, to: now)

        #expect(result.activeDaysRatio == 0)
        #expect(result.activeDays == 0)
        #expect(result.label == "Low")
    }

    /// 所有事件集中在同一星期几 → mostActiveDay 应正确识别
    @MainActor
    @Test
    func testAnalyze_MostActiveDay_Correct() async {
        let service = ActivityAnalysisService()

        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -14, to: now)!

        let cal = Calendar.current
        var monday = now
        while cal.component(.weekday, from: monday) != 2 { // 2=Monday
            monday = cal.date(byAdding: .day, value: -1, to: monday)!
        }

        let events = [
            Event(
                accountId: 1,
                eventType: .profileSnapshot,
                payload: Data(),
                source: .api,
                observedAt: monday,
                createdAt: monday
            )
        ]

        let result = await service.analyze(events: events, from: from, to: now)

        #expect(result.mostActiveDay == 2)
    }

    /// 高活跃度标签 "Highly Active"
    @MainActor
    @Test
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

        #expect(result.label == "Highly Active")
    }

    /// 中等活跃度标签 "Moderate"
    @MainActor
    @Test
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

        #expect(result.label == "Moderate")
    }

    /// 低活跃度标签 "Low"
    @MainActor
    @Test
    func testActivityLabel_Low() async {
        let service = ActivityAnalysisService()

        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let events = [makeEvent(accountId: 1, daysAgo: 0)]

        let result = await service.analyze(events: events, from: from, to: now)

        #expect(result.label == "Low")
    }

    // MARK: - ComparisonService

    /// 当前 > 前一期 → 方向 UP
    @MainActor
    @Test
    func testCompare_Growing_Up() async {
        let service = ComparisonService()

        let result = await service.compare(
            currentSnapshots: [makeSnapshot(followers: 200)],
            previousSnapshots: [makeSnapshot(followers: 100)]
        ) { $0.followersCount }

        #expect(result.direction == .up)
        #expect(result.percentChange == 100.0)
    }

    /// 当前 < 前一期 → 方向 DOWN
    @MainActor
    @Test
    func testCompare_Declining_Down() async {
        let service = ComparisonService()

        let result = await service.compare(
            currentSnapshots: [makeSnapshot(followers: 80)],
            previousSnapshots: [makeSnapshot(followers: 100)]
        ) { $0.followersCount }

        #expect(result.direction == .down)
        #expect(result.percentChange == -20.0)
    }

    /// 变化 < 0.5% → 方向 FLAT
    @MainActor
    @Test
    func testCompare_Flat_WithinThreshold() async {
        let service = ComparisonService()

        let result = await service.compare(
            currentSnapshots: [makeSnapshot(followers: 1000)],
            previousSnapshots: [makeSnapshot(followers: 1001)]
        ) { $0.followersCount }

        #expect(result.direction == .flat)
    }

    /// 前一周期为空 → 优雅处理
    @MainActor
    @Test
    func testCompare_WithEmptyPrevious_HandlesGracefully() async {
        let service = ComparisonService()

        let result = await service.compare(
            currentSnapshots: [makeSnapshot(followers: 200)],
            previousSnapshots: []
        ) { $0.followersCount }

        #expect(result.currentAvg == 200.0)
        #expect(result.previousAvg == 0.0)
        #expect(result.percentChange == 0.0)
    }

    /// 百分比变化应精确计算
    @MainActor
    @Test
    func testCompare_PercentChange_CalculatedCorrectly() async {
        let service = ComparisonService()

        let result = await service.compare(
            currentSnapshots: [makeSnapshot(followers: 150)],
            previousSnapshots: [makeSnapshot(followers: 100)]
        ) { $0.followersCount }

        #expect(result.percentChange == 50.0)
        #expect(result.absoluteChange == 50.0)
    }

    // MARK: - GeoDistributionService

    /// Mock 数据应返回 9 个地区
    @MainActor
    @Test
    func testFetchDistribution_ReturnsMockRegions() async {
        let service = GeoDistributionService()

        let result = await service.fetchDistribution(accountId: 1)

        #expect(result.totalRegions == 9)
        #expect(result.regions.count == 9)
    }

    /// topRegion 应为美国
    @MainActor
    @Test
    func testFetchDistribution_HasTopRegion() async {
        let service = GeoDistributionService()

        let result = await service.fetchDistribution(accountId: 1)

        #expect(result.topRegion?.name == "United States")
        #expect(result.topRegion?.flag == "🇺🇸")
    }

    /// 地区列表不应为空
    @MainActor
    @Test
    func testFetchDistribution_RegionsNotEmpty() async {
        let service = GeoDistributionService()

        let result = await service.fetchDistribution(accountId: 42)

        #expect(!result.regions.isEmpty)

        for region in result.regions {
            #expect(!region.name.isEmpty)
            #expect(!region.flag.isEmpty)
        }
    }


    /// countryInfo 映射 — US → 🇺🇸
    @Test
    func testCountryInfo_US() {
        let info = GeoDistributionService.countryInfo(for: "US")
        #expect(info.name == "United States")
        #expect(info.flag == "🇺🇸")
    }

    /// countryInfo 映射 — JP → 🇯🇵
    @Test
    func testCountryInfo_JP() {
        let info = GeoDistributionService.countryInfo(for: "JP")
        #expect(info.name == "Japan")
        #expect(info.flag == "🇯🇵")
    }

    /// countryInfo 映射 — 未知代码 → 🌐
    @Test
    func testCountryInfo_Unknown() {
        let info = GeoDistributionService.countryInfo(for: "XX")
        #expect(info.name == "XX")
        #expect(info.flag == "🌐")
    }

    /// countryInfo 映射 — 大小写不敏感
    @Test
    func testCountryInfo_CaseInsensitive() {
        let info = GeoDistributionService.countryInfo(for: "gb")
        #expect(info.name == "United Kingdom")
        #expect(info.flag == "🇬🇧")
    }

    /// fallbackRegions 返回 9 个地区
    @Test
    func testFallbackRegions_CountIsNine() {
        let result = GeoDistributionService.fallbackRegions()
        #expect(result.totalRegions == 9)
        #expect(result.regions.count == 9)
    }

    /// fallbackRegions topRegion 为 United States
    @Test
    func testFallbackRegions_TopRegionIsUS() {
        let result = GeoDistributionService.fallbackRegions()
        #expect(result.topRegion?.name == "United States")
    }

    // MARK: - AIAnalysisService


    /// 增长趋势 → 应返回包含 summary 的洞察
    @MainActor
    @Test
    func testAnalyze_GrowingTrend_ReturnsInsights() async {
        let service = AIAnalysisService()

        let snapshots = (0..<10).map {
            makeSnapshot(followers: 100 + $0 * 5, likes: 50, views: 500)
        }

        let insights = await service.analyze(snapshots: snapshots)

        #expect(!insights.isEmpty)
        #expect(insights.contains { $0.type == .summary })
    }

    /// 粉丝急剧下降 → 应检测到 anomaly
    @MainActor
    @Test
    func testAnalyze_DecliningTrend_DetectsAnomaly() async {
        let service = AIAnalysisService()

        var snapshots: [Snapshot] = []

        for _ in 0..<7 {
            snapshots.append(makeSnapshot(followers: 200, likes: 50, views: 500))
        }

        for _ in 0..<3 {
            snapshots.append(makeSnapshot(followers: 100, likes: 50, views: 500))
        }

        let insights = await service.analyze(snapshots: snapshots)

        #expect(insights.contains { $0.type == .anomaly })
    }

    /// 稳定趋势 → 至少返回 summary 洞察
    @MainActor
    @Test
    func testAnalyze_StableTrend_ReturnsSummary() async {
        let service = AIAnalysisService()
        let snapshots = (0..<10).map { _ in
            makeSnapshot(followers: 100, likes: 30, views: 300)
        }
        let insights = await service.analyze(snapshots: snapshots)

        #expect(insights.contains { $0.type == .summary })

        let summary = insights.first { $0.type == .summary }
        #expect(summary != nil)
        #expect(summary?.severity == .info)
    }

    /// 空 Snapshot → 返回空洞察列表
    @MainActor
    @Test
    func testAnalyze_EmptySnapshots_ReturnsEmpty() async {
        let service = AIAnalysisService()
        let insights = await service.analyze(snapshots: [])
        #expect(insights.isEmpty)
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
