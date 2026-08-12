//
//  BestPostingTimeServiceTests.swift
//  FollowerTests
//
//  BestPostingTimeService 聚合逻辑单元测试 —
//  基于 MediaPost 发布时间统计互动表现（likes + comments），
//  验证小时/星期分布、归一化与最佳时段推荐。
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

    /// 聚合正确性：互动量按小时/星期累计并归一化（峰值=1.0），最佳时段为互动最多的 (wd, hr)
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
        #expect(result.bestHour == 19, "19:00 has the most engagement (60)")
        #expect(result.avgEngagementPerPost == 22.5, "(40+20+10+20)/4")

        let cal = Calendar.current
        let mon = cal.date(from: DateComponents(year: 2020, month: 1, day: 6, hour: 19))!
        let tue = cal.date(from: DateComponents(year: 2020, month: 1, day: 7, hour: 10))!
        let monWD = cal.component(.weekday, from: mon)
        let tueWD = cal.component(.weekday, from: tue)

        #expect(result.bestDay == monWD, "Monday has the most engagement (70)")
        #expect(result.hourValues[19] == 1.0, "Peak hour normalized to 1.0")
        #expect(abs(result.hourValues[9] - 10.0 / 60.0) < 0.001)
        #expect(abs(result.hourValues[10] - 20.0 / 60.0) < 0.001)
        #expect(result.dayValue(weekday: monWD) == 1.0, "Peak day normalized to 1.0")
        #expect(abs(result.dayValue(weekday: tueWD) - 20.0 / 70.0) < 0.001,
                "Tuesday = 20/(60+10)")
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
    }

    /// 单帖 → 该帖所在小时/星期为峰值 1.0
    @Test
    func testSinglePost() async {
        let service = BestPostingTimeService()
        let post = makePost(on: 2020, month: 1, day: 6, hour: 15, likes: 42, comments: 8)  // Mon 15:00
        let result = await service.analyze(from: [post])
        #expect(result.totalPosts == 1)
        #expect(result.bestHour == 15)
        #expect(result.avgEngagementPerPost == 50)
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2020, month: 1, day: 6, hour: 15))!
        let wd = cal.component(.weekday, from: date)
        #expect(result.bestDay == wd)
        #expect(result.hourValues[15] == 1.0)
        #expect(result.dayValue(weekday: wd) == 1.0)
    }

    /// 零互动帖子（likes=comments=0）→ 分布全零但不崩溃，峰值回落为 0
    @Test
    func testZeroEngagementPosts() async {
        let service = BestPostingTimeService()
        let posts = [
            makePost(on: 2020, month: 1, day: 6, hour: 9),
            makePost(on: 2020, month: 1, day: 7, hour: 10),
        ]
        let result = await service.analyze(from: posts)
        #expect(result.totalPosts == 2)
        #expect(result.hourValues.allSatisfy { $0 == 0 })
        #expect(result.avgEngagementPerPost == 0)
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
        #expect(evening?.postCount == 2, "19:00 & 20:00 fall into the same 18-20 bucket")
        #expect(evening?.avgEngagement == 30, "(40+20)/2 = avg engagement, not sum")

        let morning = result.bubbleCell(weekday: mon, hourBucket: 3)
        #expect(morning?.postCount == 1)
        #expect(morning?.avgEngagement == 10)

        // 平均互动峰值 → 最佳格（不受帖子数影响）
        #expect(result.bestBubble?.hourBucket == 6)
        #expect(result.bestBubble?.avgEngagement == 30)

        // 空桶：无样本 → avg=0, postCount=0
        let empty = result.bubbleCell(weekday: mon, hourBucket: 0)
        #expect(empty?.postCount == 0)
        #expect(empty?.avgEngagement == 0)
    }

    /// 危险情况可视化：单帖高互动 → 该桶 avg 成为峰值，但样本量=1
    /// （气泡外圈 + 中心数字会明确提示样本极少，避免误读为可信最佳时段）
    @Test
    func testSinglePostHighEngagementKeepsSampleSizeVisible() async {
        let service = BestPostingTimeService()
        let post = makePost(on: 2020, month: 1, day: 6, hour: 8, likes: 10_000)
        let result = await service.analyze(from: [post])

        let bucket = result.bubbleCell(weekday: 2, hourBucket: 2)  // Mon 06-08 桶
        #expect(bucket?.postCount == 1, "样本量必须保留，供 UI 显示")
        #expect(bucket?.avgEngagement == 10_000)
        #expect(result.bestBubble?.avgEngagement == 10_000, "单帖高互动确实会成为峰值 — UI 靠样本量提示风险")
        #expect(result.bestBubble?.postCount == 1)
    }
}
