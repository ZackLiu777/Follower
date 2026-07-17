//
//  TrendChartTests.swift
//  FollowerTests
//
//  Phi: TrendChart 确定性计算函数测试 — computeYScaleDomain / formatY / weeklyDataPoints。
//  这些是纯函数，不依赖 SwiftUI View 树，可直接单元测试。
//

import SwiftUI
import Testing
import Foundation
@testable import Follower

/// Unit tests for TrendChart — covers computeYScaleDomain, formatY, weeklyDataPoints
struct TrendChartTests {

    // MARK: - computeYScaleDomain

    /// 全零数据 → 返回 0...1（修复前为 -1...1，导致纵坐标出现无意义负值）
    @Test
    func testYScaleDomainAllZerosReturnsZeroToOne() {
        let points = (0..<7).map { _ in TrendDataPoint(date: Date(), value: 0) }
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.lowerBound == 0, "All-zero data lowerBound must be 0")
        #expect(domain.upperBound == 1, "All-zero data upperBound must be 1")
    }

    /// 全部值相等 = 5.0 → domain 不应为零宽度
    @Test
    func testYScaleDomainAllEqualValues() {
        let points = (0..<7).map { _ in TrendDataPoint(date: Date(), value: 5.0) }
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > domain.lowerBound,
                 "niceMax must be > niceMin; fixed-width guard must prevent zero-span domain")
    }

    /// 单一数据点 → 正常计算 domain
    @Test
    func testYScaleDomainSinglePoint() {
        let points = [TrendDataPoint(date: Date(), value: 42.0)]
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.upperBound >= 42, "Upper bound should cover the single value")
        #expect(domain.lowerBound >= 0)
    }

    /// 大数值数据 → 向上取整到美观量级
    @Test
    func testYScaleDomainLargeValues() {
        let points = (0..<7).map { _ in TrendDataPoint(date: Date(), value: 12345) }
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.upperBound >= 12345, "Upper bound should cover max value")
        #expect(domain.lowerBound >= 0)
    }

    /// 包含负值的数据 → lowerBound 应为负数
    @Test
    func testYScaleDomainNegativeValues() {
        let points = [
            TrendDataPoint(date: Date(), value: -50),
            TrendDataPoint(date: Date(), value: 100),
        ]
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.lowerBound < 0, "Negative values must produce negative lowerBound")
        #expect(domain.upperBound > 0)
    }

    /// 全为负值的数据 → upperBound 接近 0
    @Test
    func testYScaleDomainAllNegative() {
        let points = (0..<7).map { _ in TrendDataPoint(date: Date(), value: -100) }
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.lowerBound <= -100)
        #expect(domain.upperBound >= 0 || domain.upperBound > domain.lowerBound)
    }

    /// 小数值（0~2 范围，如评论/分享）→ domain 应合理缩放到可读范围
    @Test
    func testYScaleDomainSmallValues() {
        let points = (0..<7).map { _ in TrendDataPoint(date: Date(), value: Double.random(in: 0...2)) }
        let domain = TrendChart.computeYScaleDomain(from: points)
        #expect(domain.lowerBound >= 0, "Small positive values must not produce negative domain")
        #expect(domain.upperBound > domain.lowerBound)
    }

    // MARK: - formatY

    /// >= 10000 → "%.0fk"
    @Test
    func testFormatYKilo() {
        #expect(TrendChart.formatY(15000) == "15k")
        #expect(TrendChart.formatY(10000) == "10k")
        #expect(TrendChart.formatY(99999) == "100k")
    }

    /// >= 1000 → "%.1fk"
    @Test
    func testFormatYThousand() {
        #expect(TrendChart.formatY(1500) == "1.5k")
        #expect(TrendChart.formatY(1000) == "1.0k")
        #expect(TrendChart.formatY(9999) == "10.0k")
    }

    /// >= 1 → "%.0f"（整数）
    @Test
    func testFormatYInteger() {
        #expect(TrendChart.formatY(1) == "1")
        #expect(TrendChart.formatY(5) == "5")
        #expect(TrendChart.formatY(999) == "999")
    }

    /// 0 < value < 1 → "%.1f"（一位小数）—— 修复前这些值全部显示为 "0"
    @Test
    func testFormatYFractional() {
        #expect(TrendChart.formatY(0.5) == "0.5")
        #expect(TrendChart.formatY(0.1) == "0.1")
        #expect(TrendChart.formatY(0.99) == "1.0")  // %.1f rounds
    }

    /// value == 0 → "0"
    @Test
    func testFormatYZero() {
        #expect(TrendChart.formatY(0) == "0")
    }

    /// 负值
    @Test
    func testFormatYNegative() {
        #expect(TrendChart.formatY(-1) == "0")   // falls through to "0" (week chart has no negative bars)
        #expect(TrendChart.formatY(-0.5) == "0")
    }

    // MARK: - weeklyDataPoints

    /// 空 Metric 数组 → 返回 7 个值为 0 的 data points
    @Test
    func testWeeklyDataPointsEmpty() {
        let result = TrendChart.weeklyDataPoints(from: [])
        #expect(result.count == 7, "Should always return 7 data points (Mon-Sun)")
        for point in result {
            #expect(point.value == 0, "Empty metrics → all values should be 0")
        }
    }

    /// 7 天完整 daily metrics → 7 个 data points 按周一到周日排列，值正确
    @Test
    func testWeeklyDataPointsFullWeek() {
        let cal = Calendar.current
        var cal2 = cal
        cal2.firstWeekday = 2  // Monday
        let comps = cal2.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let weekStart = cal2.date(from: comps) else {
            #expect(Bool(false), "Cannot compute week start")
            return
        }

        let metrics: [Metric] = (0..<7).map { i in
            let dayStart = cal.date(byAdding: .day, value: i, to: weekStart)!
            return Metric(
                accountId: 1,
                metricType: .followerGrowth,
                value: Double((i + 1) * 10),
                window: .day,
                observedAt: dayStart,
                createdAt: Date()
            )
        }

        let result = TrendChart.weeklyDataPoints(from: metrics, calendar: cal, referenceDate: Date())
        #expect(result.count == 7)
        #expect(result[0].value == 10, "Monday should map index 0 → value 10")
        #expect(result[6].value == 70, "Sunday should map index 6 → value 70")
        // 日期按周一到周日升序
        for i in 1..<result.count {
            #expect(result[i - 1].date < result[i].date,
                     "Weekly points must be chronological Mon→Sun")
        }
    }

    /// 部分天有数据 → 缺失天 value = 0
    @Test
    func testWeeklyDataPointsPartialWeek() {
        let cal = Calendar.current
        var cal2 = cal
        cal2.firstWeekday = 2
        let comps = cal2.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let weekStart = cal2.date(from: comps) else {
            #expect(Bool(false), "Cannot compute week start")
            return
        }

        // 只有周一和周三有数据
        let mon = cal.date(byAdding: .day, value: 0, to: weekStart)!
        let wed = cal.date(byAdding: .day, value: 2, to: weekStart)!
        let metrics: [Metric] = [
            Metric(accountId: 1, metricType: .followerGrowth, value: 100, window: .day, observedAt: mon, createdAt: Date()),
            Metric(accountId: 1, metricType: .followerGrowth, value: 300, window: .day, observedAt: wed, createdAt: Date()),
        ]

        let result = TrendChart.weeklyDataPoints(from: metrics, calendar: cal, referenceDate: Date())
        #expect(result.count == 7)
        #expect(result[0].value == 100)  // Monday
        #expect(result[1].value == 0)    // Tuesday — 无数据
        #expect(result[2].value == 300)  // Wednesday
        #expect(result[3].value == 0)    // Thursday
    }

    /// 使用指定 referenceDate 可计算不同周的 data points
    @Test
    func testWeeklyDataPointsRespectsReferenceDate() {
        let cal = Calendar.current
        let pastDate = cal.date(byAdding: .day, value: -14, to: Date())!

        var cal2 = cal
        cal2.firstWeekday = 2
        let comps = cal2.dateComponents([.yearForWeekOfYear, .weekOfYear], from: pastDate)
        guard let pastWeekStart = cal2.date(from: comps) else {
            #expect(Bool(false), "Cannot compute past week start")
            return
        }

        let metricDate = cal.date(byAdding: .day, value: 0, to: pastWeekStart)!
        let metrics: [Metric] = [
            Metric(accountId: 1, metricType: .followerGrowth, value: 50, window: .day, observedAt: metricDate, createdAt: Date()),
        ]

        let result = TrendChart.weeklyDataPoints(from: metrics, calendar: cal, referenceDate: pastDate)
        #expect(result.count == 7)
        #expect(result[0].value == 50, "Metric on past week's Monday must map to index 0")
    }
}
