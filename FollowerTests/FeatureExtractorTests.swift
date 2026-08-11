//
//  FeatureExtractorTests.swift
//  FollowerTests
//
//  特征提取器单元测试 — FollowerHealth（增长/活跃比映射/30d 换算）、
//  ContentPerformance（空兜底/万分比换算/趋势）、TimingProfile（最佳日）、
//  FatigueIndex（疲劳阈值与惩罚）。全部纯函数，直接构造 Snapshot / Metric。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for FeatureExtractor — health, content performance, timing, fatigue
struct FeatureExtractorTests {

    // MARK: - Helpers

    /// 构造 Snapshot（observedAt 可指定）
    private func makeSnapshot(followers: Int, engagement: Double, at interval: TimeInterval) -> Snapshot {
        Snapshot(
            id: nil, accountId: 1,
            followersCount: followers, followingCount: 100, mediaCount: 10,
            engagementRate: engagement,
            totalLikes: 500, totalComments: 50, totalShares: 10, totalViews: 1000,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + interval),
            createdAt: Date()
        )
    }

    /// 构造 Metric（engagementTrend 万分比语义）
    private func makeMetric(value: Int, at interval: TimeInterval) -> Metric {
        Metric(
            id: nil, accountId: 1, metricType: .engagementTrend,
            value: value, window: .week,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + interval),
            createdAt: Date()
        )
    }

    // MARK: - extractHealth

    /// 空快照 → 全 0 活跃数据，totalFollowers 保留入参
    @Test
    func testExtractHealthEmptySnapshots() {
        let health = FeatureExtractor.extractHealth(snapshots: [], followers: 8000)
        #expect(health.activeFollowers == 0)
        #expect(health.inactiveFollowers == 0)
        #expect(health.totalFollowers == 8000)
        #expect(health.followerGrowth7d == 0)
        #expect(health.followerGrowth30d == 0)
    }

    /// 7 天增长 100 → growth7d = 100，growth30d = 100 × 30/7
    @Test
    func testExtractHealthGrowthConversion() {
        let snapshots = [
            makeSnapshot(followers: 10_000, engagement: 0.05, at: 0),
            makeSnapshot(followers: 10_100, engagement: 0.05, at: 7 * 86_400),
        ]
        let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: 10_100)
        #expect(health.followerGrowth7d == 100)
        #expect(abs(health.followerGrowth30d - 100.0 * 30.0 / 7.0) < 0.01)
    }

    /// 输入乱序 → 内部按时间排序，首尾差值正确
    @Test
    func testExtractHealthUnsortedInput() {
        let later = makeSnapshot(followers: 11_000, engagement: 0.05, at: 7 * 86_400)
        let earlier = makeSnapshot(followers: 10_000, engagement: 0.05, at: 0)
        let health = FeatureExtractor.extractHealth(snapshots: [later, earlier], followers: 11_000)
        #expect(health.followerGrowth7d == 1000)
    }

    /// 活跃比映射：avgEng 0.10 → 0.35 → active = 0.35 × followers
    @Test
    func testExtractHealthActiveRatioMapping() {
        let snapshots = [
            makeSnapshot(followers: 10_000, engagement: 0.10, at: 0),
            makeSnapshot(followers: 10_000, engagement: 0.10, at: 86_400),
        ]
        let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: 10_000)
        #expect(health.activeFollowers == 3500)
        #expect(health.inactiveFollowers == 6500)
    }

    /// 活跃比上下限：超低互动 → 0.05 下限；超高互动 → 0.50 上限
    @Test
    func testExtractHealthActiveRatioClamped() {
        let lowSnaps = [
            makeSnapshot(followers: 10_000, engagement: 0.001, at: 0),
            makeSnapshot(followers: 10_000, engagement: 0.001, at: 86_400),
        ]
        let low = FeatureExtractor.extractHealth(snapshots: lowSnaps, followers: 10_000)
        #expect(low.activeFollowers == 500)   // 0.05 × 10000

        let highSnaps = [
            makeSnapshot(followers: 10_000, engagement: 1.0, at: 0),
            makeSnapshot(followers: 10_000, engagement: 1.0, at: 86_400),
        ]
        let high = FeatureExtractor.extractHealth(snapshots: highSnaps, followers: 10_000)
        #expect(high.activeFollowers == 5000) // 0.50 × 10000
    }

    // MARK: - extractContentPerformance

    /// 空 metrics → 基线 350 兜底，各类型比率按 scale 换算（reel 最高）
    @Test
    func testExtractContentPerformanceEmptyMetrics() {
        let perf = FeatureExtractor.extractContentPerformance(metrics: [])
        #expect(perf.count == 3)   // reel / carousel / photo
        let reel = perf[.reel]
        #expect(reel != nil)
        // 350 × 1.4 / 10000 = 0.049
        #expect(abs((reel?.avgEngagement ?? 0) - 0.049) < 1e-6)
        // 空数据 → 发帖量兜底：reel = (1×1.4×1.5).rounded = 2
        #expect(reel?.recentPosts == 2)
    }

    /// 万分比换算：543 → reel = 543×1.4/10000，photo = 543×0.5/10000
    @Test
    func testExtractContentPerformanceRatioScaling() {
        let metrics = [makeMetric(value: 543, at: 0)]
        let perf = FeatureExtractor.extractContentPerformance(metrics: metrics)
        let reel = perf[.reel]
        let photo = perf[.photo]
        #expect(abs((reel?.avgEngagement ?? 0) - 543.0 * 1.40 / 10000.0) < 1e-6)
        #expect(abs((photo?.avgEngagement ?? 0) - 543.0 * 0.50 / 10000.0) < 1e-6)
    }

    /// 单点数据 → 趋势为 0（前后半段相等）
    @Test
    func testExtractContentPerformanceSinglePointNoTrend() {
        let metrics = [makeMetric(value: 543, at: 0)]
        let perf = FeatureExtractor.extractContentPerformance(metrics: metrics)
        #expect(perf[.reel]?.growthRate == 0.0)
    }

    /// 上升趋势（100 → 200）→ 各类型按 trendScale 缩放（reel 1.5、photo 0.8）
    @Test
    func testExtractContentPerformanceTrendScaling() {
        let metrics = [
            makeMetric(value: 100, at: 0),
            makeMetric(value: 200, at: 86_400),
        ]
        let perf = FeatureExtractor.extractContentPerformance(metrics: metrics)
        // baseTrend = (200-100)/100 = 1.0
        #expect(abs((perf[.reel]?.growthRate ?? 0) - 1.5) < 1e-6)
        #expect(abs((perf[.photo]?.growthRate ?? 0) - 0.8) < 1e-6)
    }

    // MARK: - extractTimingProfile

    /// 空 metrics → 不崩溃，返回格式化的时段字符串
    @Test
    func testExtractTimingProfileEmptyMetrics() {
        let profile = FeatureExtractor.extractTimingProfile(metrics: [])
        // hourStart = 17 + (bestDay % 3) → "17:00–19:00" / "18:00–20:00" / "19:00–21:00"
        let pattern = #"^\d{2}:00–\d{2}:00$"#
        #expect(profile.bestHours.range(of: pattern, options: .regularExpression) != nil)
        #expect(profile.worstHours == "03:00–06:00")
    }

    /// 全部记录落在周五（weekday=6）→ 最佳日为 6
    @Test
    func testExtractTimingProfileBestDayFromData() {
        // 2026-08-14 是周五（weekday = 6）
        let friday = DateComponents(calendar: .current, year: 2026, month: 8, day: 14).date!
        let metrics = [
            Metric(id: nil, accountId: 1, metricType: .engagementTrend, value: 500,
                   window: .week, observedAt: friday, createdAt: Date()),
            Metric(id: nil, accountId: 1, metricType: .engagementTrend, value: 600,
                   window: .week, observedAt: friday.addingTimeInterval(3600), createdAt: Date()),
        ]
        let profile = FeatureExtractor.extractTimingProfile(metrics: metrics)
        #expect(profile.bestDay == 6)
    }

    // MARK: - extractFatigue

    /// 空性能字典 → 空结果（不崩溃）
    @Test
    func testExtractFatigueEmptyPerformance() {
        let fatigue = FeatureExtractor.extractFatigue(performance: [:])
        #expect(fatigue.isEmpty)
    }

    /// 发帖量远超阈值 → isFatigued；低于 → 否
    @Test
    func testExtractFatigueDetectsFatiguedTypes() {
        // reel: 30 条 vs photo: 2 条 → total=32, avg=16, threshold = max(2, 19.2) = 19.2
        let perf: [ContentType: ContentStats] = [
            .reel: ContentStats(type: .reel, avgEngagement: 0.05, totalPosts: 60, recentPosts: 30, growthRate: -0.2),
            .photo: ContentStats(type: .photo, avgEngagement: 0.05, totalPosts: 60, recentPosts: 2, growthRate: 0.1),
        ]
        let fatigue = FeatureExtractor.extractFatigue(performance: perf)
        #expect(fatigue[.reel]?.isFatigued == true)
        #expect(fatigue[.photo]?.isFatigued == false)
        #expect(fatigue[.reel]?.posts7d == 30)
    }

    /// 疲劳惩罚有界：fatigued 时 penalty ∈ (0, 0.5]
    /// （单类型时 avg = recentPosts → threshold = 1.2×recentPosts 永不疲劳，
    ///   必须至少两类拉开差距才能触发 fatigued）
    @Test
    func testExtractFatiguePenaltyBounded() {
        let perf: [ContentType: ContentStats] = [
            .reel: ContentStats(type: .reel, avgEngagement: 0.05, totalPosts: 60, recentPosts: 30, growthRate: -0.2),
            .photo: ContentStats(type: .photo, avgEngagement: 0.05, totalPosts: 60, recentPosts: 2, growthRate: 0.1),
        ]
        let fatigue = FeatureExtractor.extractFatigue(performance: perf)
        // avg = 16 → threshold = max(2, 19.2) = 19.2 → reel 疲劳
        let penalty = fatigue[.reel]?.penalty ?? 0
        #expect(penalty > 0.0)
        #expect(penalty <= 0.5)
        // 未疲劳类型 penalty = 0
        #expect(fatigue[.photo]?.penalty == 0.0)
    }
}
