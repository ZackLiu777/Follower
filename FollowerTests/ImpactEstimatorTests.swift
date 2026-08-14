//
//  ImpactEstimatorTests.swift
//  FollowerTests
//
//  收益估算器确定性单元测试 — 转化率（快照日增量）、分类型表现、
//  最佳时段窗口、最佳日、单帖收益。全部纯函数，无 DB、无 async。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for ImpactEstimator — conversion rates / type stats / hour & day uplift
struct ImpactEstimatorTests {

    // MARK: - Helpers

    /// 构造快照（followers / views / likes 可指定）
    private func makeSnapshot(followers: Int, views: Int, likes: Int, day: Int) -> Snapshot {
        Snapshot(
            id: nil, accountId: 1,
            followersCount: followers, followingCount: 100, mediaCount: 10,
            engagementRate: 0.05,
            totalLikes: likes, totalComments: 10, totalShares: 1, totalViews: views,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400),
            createdAt: Date()
        )
    }

    /// 构造帖子（类型 / 点赞 / 评论 / 小时 / 星期可指定）
    private func makePost(
        type: MediaPostType, likes: Int, comments: Int = 0,
        hour: Int = 12, weekday: Int = 3
    ) -> MediaPost {
        // 2026-01-05 为周一（weekday=2），weekday 参数 1=周日 … 7=周六
        let base = Calendar.current.date(from: DateComponents(
            year: 2026, month: 1, day: 5 + (weekday - 2), hour: hour
        ))!
        return MediaPost(
            id: Int64(likes * 1000 + hour), accountId: 1,
            igMediaID: "ig_\(likes)_\(hour)", type: type,
            date: base, likes: likes, comments: comments,
            caption: "", mediaURL: nil, permalink: nil
        )
    }

    // MARK: - conversionRates

    /// 三天已知增量 → 转化率精确可算
    @Test
    func testConversionRatesKnownDeltas() {
        // day0→day1: ΔF=10, ΔV=4000, ΔL=40；day1→day2: ΔF=15, ΔV=5000, ΔL=50
        let snaps = [
            makeSnapshot(followers: 10_000, views: 10_000, likes: 500, day: 0),
            makeSnapshot(followers: 10_010, views: 14_000, likes: 540, day: 1),
            makeSnapshot(followers: 10_025, views: 19_000, likes: 590, day: 2),
        ]
        let rates = ImpactEstimator.conversionRates(snapshots: snaps)
        // ΣΔF = 25, ΣΔV = 9000, ΣΔL = 90
        #expect(abs(rates.followerPerView - 25.0 / 9000.0) < 1e-9)
        #expect(abs(rates.followerPerLike - 25.0 / 90.0) < 1e-9)
        #expect(abs(rates.viewsPerLike - 9000.0 / 90.0) < 1e-9)
    }

    /// 负增量（取关 / 浏览下降）不参与转化率分子 — 只衡量获得侧
    @Test
    func testConversionRatesNegativeDeltasClamped() {
        // day0→day1: ΔF=-5（取关）→ 记 0；ΔV=1000
        // day1→day2: ΔF=+20；ΔV=2000
        let snaps = [
            makeSnapshot(followers: 10_000, views: 10_000, likes: 500, day: 0),
            makeSnapshot(followers: 9_995, views: 11_000, likes: 520, day: 1),
            makeSnapshot(followers: 10_015, views: 13_000, likes: 560, day: 2),
        ]
        let rates = ImpactEstimator.conversionRates(snapshots: snaps)
        #expect(abs(rates.followerPerView - 20.0 / 3000.0) < 1e-9)
    }

    /// 单条快照 → 全 0（无增量可算）
    @Test
    func testConversionRatesSingleSnapshotZero() {
        let rates = ImpactEstimator.conversionRates(snapshots: [makeSnapshot(followers: 100, views: 100, likes: 5, day: 0)])
        #expect(rates.followerPerView == 0)
        #expect(rates.followerPerLike == 0)
        #expect(rates.viewsPerLike == 0)
    }

    /// 零浏览增量 → followerPerView 为 0（除零保护）
    @Test
    func testConversionRatesZeroViews() {
        let snaps = [
            makeSnapshot(followers: 10_000, views: 10_000, likes: 500, day: 0),
            makeSnapshot(followers: 10_010, views: 10_000, likes: 520, day: 1),
        ]
        let rates = ImpactEstimator.conversionRates(snapshots: snaps)
        #expect(rates.followerPerView == 0)
        #expect(abs(rates.followerPerLike - 10.0 / 20.0) < 1e-9)
    }

    /// 输入乱序 → 内部排序后增量正确
    @Test
    func testConversionRatesUnsortedInput() {
        let snaps = [
            makeSnapshot(followers: 10_010, views: 14_000, likes: 540, day: 1),
            makeSnapshot(followers: 10_000, views: 10_000, likes: 500, day: 0),
        ]
        let rates = ImpactEstimator.conversionRates(snapshots: snaps)
        #expect(abs(rates.followerPerLike - 10.0 / 40.0) < 1e-9)
    }

    // MARK: - typeStats

    /// 各类型真实平均互动 / 数量 / 趋势
    @Test
    func testTypeStatsRealAverages() {
        // reel: 2 条（100+50, 120+60）→ avgLikes=110, avgComments=55, avgEng=165
        // photo: 1 条（20, 5）→ avgEng=25
        let posts = [
            makePost(type: .video, likes: 100, comments: 50, hour: 19),
            makePost(type: .video, likes: 120, comments: 60, hour: 20),
            makePost(type: .image, likes: 20, comments: 5, hour: 10),
        ]
        let stats = ImpactEstimator.typeStats(posts: posts)
        #expect(stats.count == 2)
        let reel = stats[.reel]
        #expect(reel != nil)
        #expect(abs((reel?.avgLikes ?? 0) - 110.0) < 1e-9)
        #expect(abs((reel?.avgComments ?? 0) - 55.0) < 1e-9)
        #expect(abs((reel?.avgEngagement ?? 0) - 165.0) < 1e-9)
        #expect(reel?.postCount == 2)
        // 上升趋势（50→60）：(60-50)/50 = 0.2
        #expect(abs((reel?.growthRate ?? 0) - 0.2) < 1e-9)
        #expect(abs((stats[.photo]?.avgEngagement ?? 0) - 25.0) < 1e-9)
    }

    /// 空帖子 → 空结果（不再有兜底类型）
    @Test
    func testTypeStatsEmptyPosts() {
        #expect(ImpactEstimator.typeStats(posts: []).isEmpty)
    }

    /// 近 7 天发帖数统计
    @Test
    func testTypeStatsRecent7dCount() {
        let now = Date()
        let recent = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let old = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let posts = [
            MediaPost(id: 1, accountId: 1, igMediaID: "a", type: .video, date: recent,
                likes: 10, comments: 0, caption: "", mediaURL: nil, permalink: nil),
            MediaPost(id: 2, accountId: 1, igMediaID: "b", type: .video, date: old,
                likes: 10, comments: 0, caption: "", mediaURL: nil, permalink: nil),
        ]
        let stats = ImpactEstimator.typeStats(posts: posts)
        #expect(stats[.reel]?.recent7dCount == 1)
        #expect(stats[.reel]?.postCount == 2)
    }

    /// 单点类型数据 → 趋势为 0（无前后段可比）
    @Test
    func testTypeStatsSinglePostNoTrend() {
        let stats = ImpactEstimator.typeStats(posts: [makePost(type: .image, likes: 10)])
        #expect(stats[.photo]?.growthRate == 0.0)
    }

    // MARK: - hourWindowRanks（保留：DecisionContext.secondBestHour 使用）

    /// 窗口排名：高互动集中在 21 点 → 第一窗口 21 点
    @Test
    func testHourWindowRanksFindsPeak() {
        let posts = [
            makePost(type: .video, likes: 10, hour: 9, weekday: 1),
            makePost(type: .video, likes: 10, hour: 9, weekday: 2),
            makePost(type: .image, likes: 100, hour: 21, weekday: 3),
            makePost(type: .image, likes: 100, hour: 21, weekday: 4),
        ]
        let ranks = ImpactEstimator.hourWindowRanks(posts: posts)
        #expect(ranks.first?.start == 21)
        #expect(ranks.count == 2)
    }

    /// 帖子 < 2 → 空排名
    @Test
    func testHourWindowRanksTooFewPosts() {
        #expect(ImpactEstimator.hourWindowRanks(posts: [makePost(type: .video, likes: 10, hour: 12)]).isEmpty)
    }

    /// 次佳窗口：第二高窗口提升 > 1 才返回
    @Test
    func testSecondBestHourWindow() {
        let posts = [
            makePost(type: .video, likes: 10, hour: 9, weekday: 1),
            makePost(type: .video, likes: 100, hour: 21, weekday: 3),
        ]
        let second = ImpactEstimator.secondBestHourWindow(posts: posts)
        // 21 点平均 100，9 点平均 10 → 第二窗口 = 9 点
        #expect(second?.start == 9)
    }

    // MARK: - perPost 收益

    /// 单帖粉丝收益 = 平均点赞 × 点赞→粉丝转化率
    @Test
    func testPerPostFollowerGain() {
        let rates = ImpactEstimator.ConversionRates(followerPerView: 0.001, followerPerLike: 0.01, viewsPerLike: 10)
        let perf = ImpactEstimator.TypePerformance(
            type: .reel, avgLikes: 500, avgComments: 20,
            avgEngagement: 520, postCount: 10, recent7dCount: 2, growthRate: 0.1
        )
        #expect(abs(ImpactEstimator.perPostFollowerGain(perf, rates: rates) - 5.0) < 1e-9)
        #expect(abs(ImpactEstimator.perPostViewsGain(perf, rates: rates) - 5000.0) < 1e-9)
    }

    /// 零转化率 → 收益为 0（数据不足时不会出现虚假收益）
    @Test
    func testPerPostGainZeroRates() {
        let rates = ImpactEstimator.ConversionRates(followerPerView: 0, followerPerLike: 0, viewsPerLike: 0)
        let perf = ImpactEstimator.TypePerformance(
            type: .reel, avgLikes: 500, avgComments: 0,
            avgEngagement: 500, postCount: 5, recent7dCount: 1, growthRate: 0
        )
        #expect(ImpactEstimator.perPostFollowerGain(perf, rates: rates) == 0)
        #expect(ImpactEstimator.perPostViewsGain(perf, rates: rates) == 0)
    }

    // MARK: - ContentType 映射

    /// MediaPostType → ContentType 映射完整
    @Test
    func testContentTypeMapping() {
        #expect(ContentType(mediaType: .video) == .reel)
        #expect(ContentType(mediaType: .carousel) == .carousel)
        #expect(ContentType(mediaType: .image) == .photo)
    }
}
