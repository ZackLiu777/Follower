//
//  BestPostingTimeServiceTests.swift
//  FollowerTests
//
//  BestPostingTimeService 单元测试（v2 统计层）：
//  - 历史层：小时/星期归一化、气泡矩阵（原始平均值）
//  - 推荐层：shrinkage 收缩性质、滑动 3h 窗口、bootstrap 确定性、
//    confidence 分档、score 范围
//

import Testing
import Foundation
@testable import Follower

/// BestPostingTimeService 聚合测试
struct BestPostingTimeServiceTests {

    /// 固定日期构造 MediaPost（与运行日期无关，weekday 确定）：
    /// 2020-01-06 = 周一，2020-01-07 = 周二
    private func makePost(on year: Int, month: Int, day: Int, hour: Int,
                          likes: Int = 0, comments: Int = 0) -> MediaPost {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? Date()
        return MediaPost(
            id: 0, accountId: 1, igMediaID: "post-\(year)-\(month)-\(day)-\(hour)",
            type: .image, date: date, likes: likes, comments: comments,
            caption: "", mediaURL: nil, permalink: nil
        )
    }

    // ───────────────────────── 历史层 ─────────────────────────

    /// 聚合正确性：互动量按小时/星期累计并归一化（峰值=1.0）
    @Test
    func testAggregatesHourAndDay() async {
        let service = BestPostingTimeService()
        let posts = [
            makePost(on: 2020, month: 1, day: 6, hour: 19, likes: 30, comments: 10),  // Mon 19:00 → 40
            makePost(on: 2020, month: 1, day: 6, hour: 19, likes: 15, comments: 5),   // Mon 19:00 → +20（累计 60）
            makePost(on: 2020, month: 1, day: 6, hour: 9, likes: 8, comments: 2),     // Mon 09:00 → 10
            makePost(on: 2020, month: 1, day: 7, hour: 10, likes: 20, comments: 0),   // Tue 10:00 → 20
        ]
        let result = await service.analyze(from: posts)

        #expect(result.totalPosts == 4)
        #expect(result.avgEngagementPerPost == 22.5, "(40+20+10+20)/4")
        #expect(result.accountAverageEngagement == 22.5)

        // 历史层：19 点原始平均 30 为峰值
        #expect(result.hourValues[19] == 1.0, "Peak hour normalized to 1.0")
        #expect(abs(result.hourValues[9] - 10.0 / 30.0) < 0.001)

        let cal = Calendar.current
        let mon = cal.date(from: DateComponents(year: 2020, month: 1, day: 6, hour: 19))!
        let tue = cal.date(from: DateComponents(year: 2020, month: 1, day: 7, hour: 10))!
        let monWD = cal.component(.weekday, from: mon)
        let tueWD = cal.component(.weekday, from: tue)

        #expect(result.bestDay == monWD, "Monday has the most engagement (70)")
        #expect(result.dayValue(weekday: monWD) == 1.0)
        #expect(abs(result.dayValue(weekday: tueWD) - 20.0 / (70.0 / 3.0)) < 0.001)
        #expect(!result.peakDescription.isEmpty)
    }

    /// 空输入 → 空结果，不崩溃
    @Test
    func testEmptyPosts() async {
        let service = BestPostingTimeService()
        let result = await service.analyze(from: [])
        #expect(result.totalPosts == 0)
        #expect(result.hourValues.allSatisfy { $0 == 0 })
        #expect(result.dayValues.allSatisfy { $0 == 0 })
        #expect(result.avgEngagementPerPost == 0)
        #expect(result.recommendation.score == 0)
        #expect(result.confidence == .low)
    }

    /// 单帖 → 历史层峰值正确；推荐层为低置信（样本不足，不宣称可信最佳）
    @Test
    func testSinglePost() async {
        let service = BestPostingTimeService()
        let post = makePost(on: 2020, month: 1, day: 6, hour: 15, likes: 42, comments: 8)  // Mon 15:00
        let result = await service.analyze(from: [post])
        #expect(result.totalPosts == 1)
        #expect(result.avgEngagementPerPost == 50)
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2020, month: 1, day: 6, hour: 15))!
        let wd = cal.component(.weekday, from: date)
        #expect(result.hourValues[15] == 1.0)
        #expect(result.dayValue(weekday: wd) == 1.0)
        // 推荐层：样本 1 < 5 → low confidence（不伪精确）
        #expect(result.confidence == .low)
        #expect(result.recommendation.sampleCount <= 3)
    }

    /// 气泡矩阵聚合：按 (weekday, 3 小时桶) 聚合平均互动与样本量（56 格）
    @Test
    func testBubbleMatrixAggregates() async {
        let service = BestPostingTimeService()
        let posts = [
            makePost(on: 2020, month: 1, day: 6, hour: 19, likes: 30, comments: 10),  // Mon 18-20 桶
            makePost(on: 2020, month: 1, day: 6, hour: 20, likes: 15, comments: 5),   // Mon 18-20 桶
            makePost(on: 2020, month: 1, day: 6, hour: 9, likes: 8, comments: 2),     // Mon 09-11 桶
        ]
        let result = await service.analyze(from: posts)

        #expect(result.matrixCells.count == 56, "7 days × 8 buckets")

        let mon = Calendar.current.component(.weekday, from: makePost(on: 2020, month: 1, day: 6, hour: 0).date)
        let evening = result.bubbleCell(weekday: mon, hourBucket: 6)
        #expect(evening?.postCount == 2)
        #expect(evening?.avgEngagement == 30, "(40+20)/2 = avg engagement, not sum")

        let morning = result.bubbleCell(weekday: mon, hourBucket: 3)
        #expect(morning?.postCount == 1)
        #expect(morning?.avgEngagement == 10)

        #expect(result.bestBubble?.hourBucket == 6)
        #expect(result.bestBubble?.avgEngagement == 30)
    }

    // ───────────────────────── 推荐层（v2 统计） ─────────────────────────

    /// 收缩性质：μ̂ 严格介于 μ 与 μ_global 之间；样本越少越靠近全局
    @Test
    func testShrunkMeanPullsTowardGlobal() {
        let global = 100.0
        // n=2, μ=500 → 介于 100 与 500 之间，且明显低于原始 500
        let small = BestPostingTimeService.shrunkMean(n: 2, sum: 1000, muGlobal: global)
        #expect(small > global && small < 500, "收缩后应在 μ 与 μ_global 之间")
        #expect(small < 300, "n=2 时应强烈向基线收缩")
        // n=30 → 接近自身均值 500
        let large = BestPostingTimeService.shrunkMean(n: 30, sum: 15000, muGlobal: global)
        #expect(large > 400 && large < 500, "大样本应主要信任自身均值")
        // n=0 → 纯基线
        #expect(BestPostingTimeService.shrunkMean(n: 0, sum: 0, muGlobal: global) == global)
    }

    /// 滑动 3h 窗口：高互动单小时 → 推荐窗口包含该小时
    @Test
    func testWindowCoversPeakHour() async {
        let service = BestPostingTimeService()
        // 20 帖都在周一 19:00（高互动），5 帖散布 9:00 低互动
        var posts: [MediaPost] = []
        for i in 0..<20 {
            posts.append(makePost(on: 2020, month: 1, day: 6, hour: 19, likes: 100 + i))
        }
        for i in 0..<5 {
            posts.append(makePost(on: 2020, month: 1, day: 6, hour: 9, likes: 5 + i))
        }
        let result = await service.analyze(from: posts)
        let rec = result.recommendation
        // 推荐窗口（起始 + 2 小时，跨 0 点环绕）必须覆盖 19:00
        let covered = (0..<BestPostingTimeService.windowHours).contains {
            (rec.startHour + $0) % 24 == 19
        }
        #expect(covered, "推荐窗口应覆盖峰值小时 19:00，实际 \(rec.startHour)")
        #expect(rec.sampleCount >= 20)
        #expect(result.confidence == .high, "窗口样本 20 ≥ 20 → high")
    }

    /// bootstrap 确定性：同输入两次分析 → 相同 P(best)；且 P ∈ [0,1]
    @Test
    func testBootstrapDeterministic() async {
        let service = BestPostingTimeService()
        var posts: [MediaPost] = []
        for i in 0..<30 {
            posts.append(makePost(on: 2020, month: 1, day: 6 + i % 5, hour: 12 + i % 10,
                                  likes: 50 + i * 3))
        }
        let r1 = await service.analyze(from: posts)
        let r2 = await service.analyze(from: posts)
        #expect(r1.recommendation.probabilityOfBeingBest == r2.recommendation.probabilityOfBeingBest,
                "固定 seed → bootstrap 结果确定")
        #expect(r1.recommendation.probabilityOfBeingBest >= 0)
        #expect(r1.recommendation.probabilityOfBeingBest <= 1)
        #expect(r1.recommendation.score >= 1 && r1.recommendation.score <= 100)
    }

    /// confidence 分档：<5 low / 5-19 medium / ≥20 high
    @Test
    func testConfidenceLevels() async {
        let service = BestPostingTimeService()
        // low：单帖
        let low = await service.analyze(from: [makePost(on: 2020, month: 1, day: 6, hour: 15, likes: 10)])
        #expect(low.confidence == .low)

        // medium：窗口 8 帖（高互动）+ 10 帖低互动分散在其他时段（制造基线差）
        var medPosts: [MediaPost] = []
        for i in 0..<8 {
            medPosts.append(makePost(on: 2020, month: 1, day: 6, hour: 18, likes: 100 + i))
        }
        for i in 0..<10 {
            medPosts.append(makePost(on: 2020, month: 1, day: 6, hour: 9, likes: 10 + i))
        }
        let med = await service.analyze(from: medPosts)
        #expect(med.recommendation.sampleCount == 8)
        #expect(med.confidence == .medium)

        // high：窗口 25 帖（高互动）+ 10 帖低互动分散（制造基线差）
        var highPosts: [MediaPost] = []
        for i in 0..<25 {
            highPosts.append(makePost(on: 2020, month: 1, day: 6, hour: 18, likes: 100 + i))
        }
        for i in 0..<10 {
            highPosts.append(makePost(on: 2020, month: 1, day: 6, hour: 9, likes: 5 + i))
        }
        let high = await service.analyze(from: highPosts)
        #expect(high.recommendation.sampleCount >= 20)
        #expect(high.confidence == .high)
    }

    /// 推荐字段完整性：lift / expectedEngagement / peakDescription 合理
    @Test
    func testRecommendationFields() async {
        let service = BestPostingTimeService()
        var posts: [MediaPost] = []
        for i in 0..<20 {
            posts.append(makePost(on: 2020, month: 1, day: 6, hour: 18, likes: 200 + i))
        }
        for i in 0..<10 {
            posts.append(makePost(on: 2020, month: 1, day: 7, hour: 8, likes: 20 + i))
        }
        let result = await service.analyze(from: posts)
        let rec = result.recommendation
        #expect(rec.liftVsAverage > 0, "18 点互动远高于整体 → lift 为正")
        #expect(rec.expectedEngagement > result.accountAverageEngagement)
        #expect(rec.weekday >= 1 && rec.weekday <= 7)
        #expect(rec.startHour >= 0 && rec.startHour <= 23)
        #expect(rec.endHour >= 0 && rec.endHour <= 23)
        #expect(!result.peakDescription.isEmpty)
    }
}
