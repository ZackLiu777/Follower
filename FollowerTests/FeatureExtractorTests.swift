//
//  FeatureExtractorTests.swift
//  FollowerTests
//
//  特征提取器单元测试 — FollowerHealth（增长速率/活跃比映射）、
//  ContentPerformance（真实帖子分类型表现）、TimingProfile（真实时段分布）、
//  FatigueIndex（疲劳阈值与惩罚）、ImpactSummary（转化率与单帖收益）。
//  全部纯函数，直接构造 Snapshot / MediaPost。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for FeatureExtractor — health, content performance, timing, fatigue, impact
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

    /// 构造帖子（类型 / 点赞 / 评论 / 小时可指定）
    private func makePost(type: MediaPostType, likes: Int, comments: Int = 0, hour: Int = 12) -> MediaPost {
        let base = Calendar.current.date(from: DateComponents(
            year: 2026, month: 1, day: 5, hour: hour
        ))!
        return MediaPost(
            id: Int64(likes + hour), accountId: 1,
            igMediaID: "ig_\(likes)_\(hour)", type: type,
            date: base, likes: likes, comments: comments,
            caption: "", mediaURL: nil, permalink: nil
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

    /// 7 天增长 100 → growth7d = 100，growth30d = 100 × 30/7（速率换算）
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

    /// 长观测跨度 → 速率按 7 天换算（90 天涨 90 → 周速率 7）
    @Test
    func testExtractHealthRateScaledToSevenDays() {
        let snapshots = [
            makeSnapshot(followers: 10_000, engagement: 0.05, at: 0),
            makeSnapshot(followers: 10_090, engagement: 0.05, at: 90 * 86_400),
        ]
        let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: 10_090)
        #expect(abs(health.followerGrowth7d - 90.0 * 7.0 / 90.0) < 0.01)
    }

    /// 7 天浏览增量：快照 totalViews 差值按观测跨度换算（负浏览增量截断为 0）
    @Test
    func testExtractHealthViewsGrowth7d() {
        let s0 = Snapshot(id: nil, accountId: 1, followersCount: 10_000, followingCount: 100,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 500, totalComments: 50,
            totalShares: 10, totalViews: 20_000,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000), createdAt: Date())
        let s1 = Snapshot(id: nil, accountId: 1, followersCount: 10_100, followingCount: 100,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 500, totalComments: 50,
            totalShares: 10, totalViews: 27_000,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + 7 * 86_400), createdAt: Date())
        let health = FeatureExtractor.extractHealth(snapshots: [s0, s1], followers: 10_100)
        // 7 天内浏览 +7000 → viewsGrowth7d = 7000
        #expect(abs(health.viewsGrowth7d - 7000.0) < 0.01)
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

    /// 空帖子 → 空结果（真实数据驱动，无编造类型）
    @Test
    func testExtractContentPerformanceEmptyPosts() {
        #expect(FeatureExtractor.extractContentPerformance(posts: []).isEmpty)
    }

    /// 真实帖子 → 各类型真实平均互动 / 数量
    @Test
    func testExtractContentPerformanceRealPosts() {
        let posts = [
            makePost(type: .video, likes: 100, comments: 50),
            makePost(type: .video, likes: 120, comments: 60),
            makePost(type: .image, likes: 20, comments: 5),
        ]
        let perf = FeatureExtractor.extractContentPerformance(posts: posts)
        #expect(perf.count == 2)   // reel + photo（无 carousel）
        #expect(abs((perf[.reel]?.avgEngagement ?? 0) - 165.0) < 1e-9)
        #expect(perf[.reel]?.totalPosts == 2)
        #expect(abs((perf[.photo]?.avgEngagement ?? 0) - 25.0) < 1e-9)
    }

    /// 帖子趋势：后段互动高于前段 → growthRate > 0
    @Test
    func testExtractContentPerformanceGrowthTrend() {
        let posts = [
            makePost(type: .video, likes: 50, hour: 10),
            makePost(type: .video, likes: 50, hour: 11),
            makePost(type: .video, likes: 150, hour: 12),
            makePost(type: .video, likes: 150, hour: 13),
        ]
        let perf = FeatureExtractor.extractContentPerformance(posts: posts)
        // 前段平均 50，后段平均 150 → growthRate = (150-50)/50 = 2.0
        #expect(abs((perf[.reel]?.growthRate ?? 0) - 2.0) < 1e-9)
    }

    // MARK: - extractTimingProfile

    /// 空帖子 → 不崩溃，返回兜底时段（uplift 1.0）
    @Test
    func testExtractTimingProfileEmptyPosts() {
        let profile = FeatureExtractor.extractTimingProfile(posts: [])
        let pattern = #"^\d{2}:00–\d{2}:00$"#
        #expect(profile.bestHours.range(of: pattern, options: .regularExpression) != nil)
        #expect(profile.worstHours.range(of: pattern, options: .regularExpression) != nil)
    }

    /// 高互动帖子集中在 21 点 → 最佳时段包含 21:00
    @Test
    func testExtractTimingProfileBestHourFromData() {
        let posts = [
            makePost(type: .video, likes: 10, hour: 9),
            makePost(type: .video, likes: 10, hour: 9),
            makePost(type: .image, likes: 100, hour: 21),
            makePost(type: .image, likes: 100, hour: 21),
        ]
        let profile = FeatureExtractor.extractTimingProfile(posts: posts)
        #expect(profile.bestHours.contains("21:00"))
        #expect(profile.worstHours.contains("09:00"))
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
    @Test
    func testExtractFatiguePenaltyBounded() {
        let perf: [ContentType: ContentStats] = [
            .reel: ContentStats(type: .reel, avgEngagement: 0.05, totalPosts: 60, recentPosts: 30, growthRate: -0.2),
            .photo: ContentStats(type: .photo, avgEngagement: 0.05, totalPosts: 60, recentPosts: 2, growthRate: 0.1),
        ]
        let fatigue = FeatureExtractor.extractFatigue(performance: perf)
        let penalty = fatigue[.reel]?.penalty ?? 0
        #expect(penalty > 0.0)
        #expect(penalty <= 0.5)
        #expect(fatigue[.photo]?.penalty == 0.0)
    }

    // MARK: - extractImpact

    /// 快照 + 帖子 → 转化率与单帖收益正确联动
    @Test
    func testExtractImpactConvertsRealData() {
        // ΔF=25, ΔL=50, ΔV=4000
        let s0 = Snapshot(id: nil, accountId: 1, followersCount: 10_000, followingCount: 100,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 500, totalComments: 50,
            totalShares: 10, totalViews: 10_000,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000), createdAt: Date())
        let s1 = Snapshot(id: nil, accountId: 1, followersCount: 10_025, followingCount: 100,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 550, totalComments: 50,
            totalShares: 10, totalViews: 14_000,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + 86_400), createdAt: Date())
        let posts = [makePost(type: .video, likes: 100, comments: 50)]
        let impact = FeatureExtractor.extractImpact(snapshots: [s0, s1], posts: posts)
        // 转化率：followerPerLike = 25/50 = 0.5；单帖收益 = 100 × 0.5 = 50
        #expect(abs(impact.rates.followerPerLike - 0.5) < 1e-9)
        #expect(abs((impact.perPostFollowerGain[.reel] ?? -1) - 50.0) < 1e-9)
        // viewsPerLike = 4000/50 = 80 → 单帖浏览 = 100 × 80 = 8000
        #expect(abs((impact.perPostViewsGain[.reel] ?? -1) - 8000.0) < 1e-9)
        #expect(impact.bestDay >= 1 && impact.bestDay <= 7)
    }

    /// 无帖子 → 时段提升 1.0，无单帖收益（不编造）
    @Test
    func testExtractImpactNoPostsNoGains() {
        let snaps = [
            makeSnapshot(followers: 10_000, engagement: 0.05, at: 0),
            makeSnapshot(followers: 10_025, engagement: 0.05, at: 86_400),
        ]
        let impact = FeatureExtractor.extractImpact(snapshots: snaps, posts: [])
        #expect(impact.perPostFollowerGain.isEmpty)
        #expect(impact.perPostViewsGain.isEmpty)
        #expect(impact.hourUplift.uplift == 1.0)
    }

    // MARK: - extractContext

    /// 空快照 + 空帖子 + 空指标 → 不崩溃（回归：1..<0 Range 崩溃）
    @Test
    func testExtractContextEmptyDataDoesNotCrash() {
        let context = FeatureExtractor.extractContext(
            snapshots: [], posts: [], weeklyMetrics: [:], draftCount: 0)
        #expect(context.snapshotCount == 0)
        #expect(context.postsLast7d == 0)
        #expect(context.daysSinceLastPost == 0)
        #expect(context.churnDays7d == 0)
        #expect(context.lowEngagementPostCount == 0)
        #expect(context.draftCount == 0)
    }

    /// 单条快照 + 单条帖子 → 不崩溃（不足 2 点也安全）
    @Test
    func testExtractContextSinglePointDoesNotCrash() {
        let snap = makeSnapshot(followers: 10_000, engagement: 0.05, at: 0)
        let post = makePost(type: .video, likes: 100, comments: 10)
        let context = FeatureExtractor.extractContext(
            snapshots: [snap], posts: [post], weeklyMetrics: [:], draftCount: 1)
        #expect(context.snapshotCount == 1)
        #expect(context.churnDays7d == 0)
        #expect(context.longestGapDays >= 0)
    }

    /// 全量数据 → 周对比 / 取关 / 内容分布正确
    @Test
    func testExtractContextFullData() {
        // 近 7 天快照：10000 → 10020（+20 粉丝）
        let now = Date()
        let day1 = now.addingTimeInterval(-6 * 86_400)
        let day2 = now.addingTimeInterval(-86_400)
        let s1 = Snapshot(id: nil, accountId: 1, followersCount: 10_000, followingCount: 200,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 500, totalComments: 50,
            totalShares: 10, totalViews: 10_000, observedAt: day1, createdAt: Date())
        let s2 = Snapshot(id: nil, accountId: 1, followersCount: 10_020, followingCount: 200,
            mediaCount: 10, engagementRate: 0.05, totalLikes: 520, totalComments: 50,
            totalShares: 10, totalViews: 12_000, observedAt: day2, createdAt: Date())
        let post = makePost(type: .video, likes: 100, comments: 10)

        let context = FeatureExtractor.extractContext(
            snapshots: [s1, s2], posts: [post],
            weeklyMetrics: [.reachEstimate: [Metric(id: nil, accountId: 1, metricType: .reachEstimate,
                value: 5000, window: .week, observedAt: now, createdAt: Date())]],
            draftCount: 2)

        // 本周涨粉 +20，浏览 +2000
        #expect(context.weekOverWeek.followersThisWeek == 20)
        #expect(context.weekOverWeek.viewsThisWeek == 2000)
        #expect(context.followingCount == 200)
        #expect(context.draftCount == 2)
        #expect(context.typeShare[.reel] == 1.0)
        #expect(context.topPostEngagement == 110)
        #expect(context.topPostType == .reel)
    }
}
