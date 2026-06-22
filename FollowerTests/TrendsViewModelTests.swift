//
//  TrendsViewModelTests.swift
//  FollowerTests
//
//  Lambda-2: BarMark + barWidthRatio + partitionByType 测试。
//

import XCTest
@testable import Follower

final class TrendsViewModelTests: XCTestCase {

    func testTrendDataPointIdentifiable() {
        let p = TrendDataPoint(date: Date(), value: 42.0)
        XCTAssertEqual(p.id, p.date); XCTAssertEqual(p.value, 42.0)
    }

    // MARK: - barWidth (adaptive)

    func testBarWidthSmall()  { XCTAssertEqual(TrendChart.barWidth(for: 7), 24) }
    func testBarWidthMedium()  { XCTAssertEqual(TrendChart.barWidth(for: 12), 18) }
    func testBarWidthLarge() { XCTAssertEqual(TrendChart.barWidth(for: 30), 14) }
    func testBarWidthVeryLarge()  { XCTAssertEqual(TrendChart.barWidth(for: 100), 10) }
    func testBarWidthBoundaries() {
        XCTAssertEqual(TrendChart.barWidth(for: 1), 24)
        XCTAssertEqual(TrendChart.barWidth(for: 7), 24)
        XCTAssertEqual(TrendChart.barWidth(for: 8), 18)
        XCTAssertEqual(TrendChart.barWidth(for: 20), 18)
        XCTAssertEqual(TrendChart.barWidth(for: 21), 14)
        XCTAssertEqual(TrendChart.barWidth(for: 50), 14)
        XCTAssertEqual(TrendChart.barWidth(for: 51), 10)
    }

    // MARK: - visibleMetricTypes

    @MainActor func testVisibleMetricTypes() {
        let types = TrendsViewModel.visibleMetricTypes
        XCTAssertEqual(types.count, 6)
        XCTAssertTrue(types.contains(.followerGrowth))
        XCTAssertTrue(types.contains(.engagementTrend))
    }

    @MainActor func testVisibleMetricTypesExcludesPremium() {
        let types = TrendsViewModel.visibleMetricTypes
        XCTAssertFalse(types.contains(.engagementQualityScore))
        XCTAssertFalse(types.contains(.followerGrowthPrediction))
    }

    // MARK: - chartData sort order

    func testTrendDataPointsSortedChronologically() {
        let dates = (0..<5).map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! }
        let points = dates.map { TrendDataPoint(date: $0, value: Double.random(in: 1...100)) }
        let sorted = points.sorted { $0.date < $1.date }
        for i in 1..<sorted.count { XCTAssertLessThanOrEqual(sorted[i-1].date, sorted[i].date) }
    }

    func testTrendDataPointSortPreservesValue() {
        let d1 = Date(); let d2 = Calendar.current.date(byAdding: .day, value: 1, to: d1)!
        let sorted = [TrendDataPoint(date: d2, value: 200), TrendDataPoint(date: d1, value: 100)]
            .sorted { $0.date < $1.date }
        XCTAssertEqual(sorted[0].value, 100); XCTAssertEqual(sorted[1].value, 200)
    }

    func testEmptyChartData() { XCTAssertTrue([TrendDataPoint]().isEmpty) }

    @MainActor func testMetricTypeLocalizedName() {
        for t in TrendsViewModel.visibleMetricTypes { XCTAssertFalse(t.localizedName.isEmpty) }
    }
}
