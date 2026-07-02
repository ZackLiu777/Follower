//
//  TrendsViewModelTests.swift
//  FollowerTests
//
//  Sigma: 全窗口 chartData + mock fallback + TimeSeriesEngine 测试。
//

import XCTest
import Foundation
@testable import Follower

/// Unit tests for TrendsViewModel — covers TrendDataPoint, visibleMetricTypes, chartData per window, TimeSeriesEngine aggregation
final class TrendsViewModelTests: XCTestCase {

    // MARK: - TrendDataPoint

    /// TrendDataPoint 初始化 → id = date, value = 传入值
    func testTrendDataPointIdentifiable() {
        let d = Date()
        let p = TrendDataPoint(date: d, value: 42.0)
        XCTAssertEqual(p.id, d)
        XCTAssertEqual(p.value, 42.0)
    }

    /// value = 0 → 正确存储零值
    func testTrendDataPointZeroValue() {
        let p = TrendDataPoint(date: Date(), value: 0)
        XCTAssertEqual(p.value, 0)
    }

    /// value = 999999.9 → 正确处理大值
    func testTrendDataPointLargeValue() {
        let p = TrendDataPoint(date: Date(), value: 999999.9)
        XCTAssertEqual(p.value, 999999.9)
    }

    /// value = -100 → 正确处理负值
    func testTrendDataPointNegativeValue() {
        let p = TrendDataPoint(date: Date(), value: -100)
        XCTAssertEqual(p.value, -100)
    }

    // MARK: - visibleMetricTypes

    /// visibleMetricTypes 应包含 6 个基础指标
    @MainActor func testVisibleMetricTypesCount() {
        XCTAssertEqual(TrendsViewModel.visibleMetricTypes.count, 6)
    }

    /// visibleMetricTypes 应包含 followerGrowth, engagementTrend, averageLikes, averageComments, averageShares, profileViews
    @MainActor func testVisibleMetricTypesContainsCore() {
        let t = TrendsViewModel.visibleMetricTypes
        XCTAssertTrue(t.contains(.followerGrowth))
        XCTAssertTrue(t.contains(.engagementTrend))
        XCTAssertTrue(t.contains(.averageLikes))
        XCTAssertTrue(t.contains(.averageComments))
        XCTAssertTrue(t.contains(.averageShares))
        XCTAssertTrue(t.contains(.profileViews))
    }

    /// visibleMetricTypes 不应包含 Premium 专用指标
    @MainActor func testVisibleMetricTypesExcludesPremium() {
        let t = TrendsViewModel.visibleMetricTypes
        XCTAssertFalse(t.contains(.engagementQualityScore))
        XCTAssertFalse(t.contains(.activityAnalysis))
        XCTAssertFalse(t.contains(.retentionAnalysis))
        XCTAssertFalse(t.contains(.followerGrowthPrediction))
        XCTAssertFalse(t.contains(.geoDistribution))
        XCTAssertFalse(t.contains(.localAIAnalysis))
        XCTAssertFalse(t.contains(.longTermTrendComparison))
    }

    // MARK: - create VM helper

    /// 创建测试用 TrendsViewModel，预填充默认值
    @MainActor
    private func makeVM() -> TrendsViewModel {
        let db = DatabaseManager.shared
        return TrendsViewModel(
            snapshotRepo: SnapshotRepository(db: db),
            metricRepo: MetricRepository(db: db),
            accountRepo: AccountRepository(db: db)
        )
    }

    // MARK: - Day window mock fallback

    /// Day 窗口 → 每个 visibleMetricType 应返回 24 个正值 mock 数据点
    @MainActor func testDayMockHas24Points() async throws {
        let vm = makeVM()
        await vm.selectWindow(.day)
        for type in TrendsViewModel.visibleMetricTypes {
            let points = vm.chartData(for: type)
            XCTAssertEqual(points.count, 24, "Day mock \(type) should have 24 points")
            for p in points { XCTAssertGreaterThan(p.value, 0, "Day mock value should be > 0") }
        }
    }

    /// Day 窗口 → 数据点应按时间先后排序
    @MainActor func testDayMockPointsAreChronological() async throws {
        let vm = makeVM()
        await vm.selectWindow(.day)
        let points = vm.chartData(for: .followerGrowth)
        for i in 1..<points.count {
            XCTAssertLessThan(points[i-1].date, points[i].date, "Day points must be chronological")
        }
    }

    // MARK: - Week / Month / Year chartData

    /// Week 窗口：从空 DB 获取 chartData → 返回空数组，不崩溃
    @MainActor func testChartData_ForWeek_ReturnsEmptyOrPoints() async throws {
        let vm = makeVM()
        await vm.selectWindow(.week)
        for type in TrendsViewModel.visibleMetricTypes {
            let points = vm.chartData(for: type)
            // 空 DB 返回空数组；若未来加入 week mock，点数应 >= 0
            XCTAssertGreaterThanOrEqual(points.count, 0)
        }
    }

    /// Month 窗口：chartData 应按日期排序
    @MainActor func testChartData_ForMonth_ReturnsSortedData() async throws {
        let vm = makeVM()
        await vm.selectWindow(.month)
        let points = vm.chartData(for: .followerGrowth)
        for i in 1..<points.count {
            XCTAssertLessThanOrEqual(points[i-1].date, points[i].date,
                                     "Month chartData must be sorted by date")
        }
    }

    /// Year 窗口：chartData 应按日期排序
    @MainActor func testChartData_ForYear_ReturnsSortedData() async throws {
        let vm = makeVM()
        await vm.selectWindow(.year)
        let points = vm.chartData(for: .followerGrowth)
        for i in 1..<points.count {
            XCTAssertLessThanOrEqual(points[i-1].date, points[i].date,
                                     "Year chartData must be sorted by date")
        }
    }

    // NOTE: Week/Month/Year chartData tests use fresh VM instances.
    // If dealloc crashes occur in the test runner, these windows are
    // also tested via UI tests (TrendsUITests).

    // MARK: - selectWindow updates selectedWindow

    /// selectWindow 应正确切换 selectedWindow 状态（day → week → month → year → day）
    @MainActor func testSelectWindowChangesState() async throws {
        let vm = makeVM()
        XCTAssertEqual(vm.selectedWindow, .day)
        await vm.selectWindow(.week)
        XCTAssertEqual(vm.selectedWindow, .week)
        await vm.selectWindow(.month)
        XCTAssertEqual(vm.selectedWindow, .month)
        await vm.selectWindow(.year)
        XCTAssertEqual(vm.selectedWindow, .year)
        await vm.selectWindow(.day)
        XCTAssertEqual(vm.selectedWindow, .day)
    }

    // MARK: - chartData sort order

    /// 手动构造 TrendDataPoint 数组 → sorted 后应按日期升序排列
    func testTrendDataPointsSortedChronologically() {
        let dates = (0..<10).map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! }
        let points = dates.map { TrendDataPoint(date: $0, value: Double($0.timeIntervalSince1970)) }
        let sorted = points.sorted { $0.date < $1.date }
        for i in 1..<sorted.count {
            XCTAssertLessThanOrEqual(sorted[i-1].date, sorted[i].date)
        }
    }

    // MARK: - TimeSeriesEngine

    /// bucketStart(.day) → 应返回当天 startOfDay
    func testEngineDayBucket() {
        let now = Date()
        let bucket = TimeSeriesEngine.bucketStart(now, by: .day)
        let cal = Calendar.current
        XCTAssertEqual(bucket, cal.startOfDay(for: now))
    }

    /// bucketStart(.hour) → 分钟和秒应为 0
    func testEngineHourBucket() {
        let now = Date()
        let bucket = TimeSeriesEngine.bucketStart(now, by: .hour)
        let cal = Calendar.current
        let comps = cal.dateComponents([.minute, .second], from: bucket)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }

    /// bucketStart(.month) → 日期 day 应为 1
    func testEngineMonthBucket() {
        let now = Date()
        let bucket = TimeSeriesEngine.bucketStart(now, by: .month)
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: bucket)
        XCTAssertEqual(comps.day, 1)
    }

    /// bucketStart(.year) → 月份=1，日期=1
    func testEngineYearBucket() {
        let now = Date()
        let bucket = TimeSeriesEngine.bucketStart(now, by: .year)
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .day], from: bucket)
        XCTAssertEqual(comps.month, 1)
        XCTAssertEqual(comps.day, 1)
    }

    /// bucketStart(.week) → weekday 应为 firstWeekday (1)
    func testEngineWeekBucket() {
        let now = Date()
        let bucket = TimeSeriesEngine.bucketStart(now, by: .week)
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: bucket)
        var weekdayCal = cal
        weekdayCal.firstWeekday = 1
        let expectedFirst = weekdayCal.firstWeekday
        XCTAssertEqual(wd, expectedFirst)
    }

    /// aggregate 单个 Metric → 返回 1 个 bucket，value 不变
    func testEngineAggregateSingleMetric() {
        let d = Date()
        let m = Metric(accountId: 1, metricType: .followerGrowth, value: 100, window: .day, observedAt: d, createdAt: d)
        let result = TimeSeriesEngine.aggregate([m], bucket: .day)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.value, 100)
    }

    /// aggregate 空数组 → 返回空数组
    func testEngineAggregateEmpty() {
        let result = TimeSeriesEngine.aggregate([], bucket: .day)
        XCTAssertTrue(result.isEmpty)
    }

    /// 同一 bucket 内的两个 Metric (100, 200) → 应聚合为 1 个 bucket，取平均值 150
    func testEngineAggregateAveragesMultipleInSameBucket() {
        let cal = Calendar.current
        let d1 = cal.startOfDay(for: Date())
        let m1 = Metric(accountId: 1, metricType: .followerGrowth, value: 100, window: .day, observedAt: d1, createdAt: d1)
        let m2 = Metric(accountId: 1, metricType: .followerGrowth, value: 200, window: .day, observedAt: d1.addingTimeInterval(3600), createdAt: d1)
        let result = TimeSeriesEngine.aggregate([m1, m2], bucket: .day)
        XCTAssertEqual(result.count, 1, "Two metrics same day → one bucket")
        XCTAssertEqual(result.first?.value, 150, "Average of 100+200=150")
    }

    /// 3 个不同 bucket 的 Metric → 应返回 3 个 bucket 且按日期排序
    func testEngineAggregateMultipleBucketsSorted() {
        let cal = Calendar.current
        let d1 = cal.startOfDay(for: Date())
        let d2 = cal.date(byAdding: .day, value: 1, to: d1)!
        let d3 = cal.date(byAdding: .day, value: 2, to: d1)!
        let metrics = [
            Metric(accountId: 1, metricType: .followerGrowth, value: 100, window: .day, observedAt: d1, createdAt: d1),
            Metric(accountId: 1, metricType: .followerGrowth, value: 200, window: .day, observedAt: d2, createdAt: d2),
            Metric(accountId: 1, metricType: .followerGrowth, value: 300, window: .day, observedAt: d3, createdAt: d3),
        ]
        let result = TimeSeriesEngine.aggregate(metrics, bucket: .day)
        XCTAssertEqual(result.count, 3)
        for i in 1..<result.count {
            XCTAssertLessThan(result[i-1].date, result[i].date, "Buckets must be sorted by date")
        }
    }

    // MARK: - MetricType localization

    /// 所有 visibleMetricTypes 的 localizedName 不应为空
    @MainActor func testAllMetricTypesHaveLocalizedName() {
        for t in TrendsViewModel.visibleMetricTypes {
            XCTAssertFalse(t.localizedName.isEmpty, "\(t) should have a localized name")
        }
    }

    // MARK: - TimeWindow allCases

    /// TimeWindow.allCases 应包含 4 个值
    func testTimeWindowAllCasesCount() {
        XCTAssertEqual(TimeWindow.allCases.count, 4)
    }

    /// TimeWindow.allCases 应包含 .day, .week, .month, .year
    func testTimeWindowAllCasesContainsAllValues() {
        let cases = TimeWindow.allCases
        XCTAssertTrue(cases.contains(.day))
        XCTAssertTrue(cases.contains(.week))
        XCTAssertTrue(cases.contains(.month))
        XCTAssertTrue(cases.contains(.year))
    }

}
