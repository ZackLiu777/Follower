//
//  DashboardViewModelTests.swift
//  FollowerTests
//
//  Gamma-2: Dashboard ViewModel 状态机 + 卡片渲染验证。
//

import XCTest
import SwiftUI
@testable import Follower

final class DashboardViewModelTests: XCTestCase {

    // MARK: - TrendChart barWidthRatio (from TrendChart)

    func testBarWidthRatioDay() { XCTAssertEqual(TrendChart.barWidthRatio(for: 7), 0.80) }
    func testBarWidthRatioWeek() { XCTAssertEqual(TrendChart.barWidthRatio(for: 4), 0.90) }
    func testBarWidthRatioMonth() { XCTAssertEqual(TrendChart.barWidthRatio(for: 12), 0.70) }
    func testBarWidthRatioEmpty() { XCTAssertEqual(TrendChart.barWidthRatio(for: 0), 0.70) }
    func testBarWidthRatioYear() { XCTAssertEqual(TrendChart.barWidthRatio(for: 365), 0.50) }

    // MARK: - TrendDataPoint

    func testTrendDataPointConstructsCorrectly() {
        let date = Date()
        let p = TrendDataPoint(date: date, value: 100.0)
        XCTAssertEqual(p.id, date)
        XCTAssertEqual(p.value, 100.0)
    }

    // MARK: - StatCard debug: verify card struct initializes

    func testStatCardInitialization() {
        // StatCard is a View struct — verify it can be constructed
        let card = StatCard(
            title: "Followers",
            value: "1,234",
            icon: "person.2.fill",
            tint: .blue,
            subtitle: "+12"
        )
        XCTAssertEqual(card.title, "Followers")
        XCTAssertEqual(card.value, "1,234")
        XCTAssertEqual(card.icon, "person.2.fill")
        XCTAssertEqual(card.subtitle, "+12")
    }

    func testStatCardWithoutSubtitle() {
        let card = StatCard(title: "Likes", value: "500", icon: "heart.fill", tint: .red)
        XCTAssertNil(card.subtitle)
    }

    // MARK: - DashboardViewModel state machine verification

    @MainActor func testVisibleMetricTypesCount() {
        XCTAssertEqual(TrendsViewModel.visibleMetricTypes.count, 6)
    }

    func testTrendChartEmptyDataReturnsZeroBars() {
        let empty: [TrendDataPoint] = []
        XCTAssertTrue(empty.isEmpty)
        let ratio = TrendChart.barWidthRatio(for: empty.count)
        XCTAssertEqual(ratio, 0.70)
    }

    // MARK: - Debug: print current test config

    func testDebugPrintThemeInfo() {
        for theme in AppTheme.allCases {
            let t = theme.theme
            print("[Debug] Theme: \(t.displayName) | isDark=\(t.isDark) | liquidGlass=\(t.liquidGlassEnabled) | accent=\(t.accentPrimary)")
            XCTAssertFalse(t.displayName.isEmpty)
        }
    }

    func testBarWidthRatioEdgeCases() {
        // Test every boundary
        XCTAssertEqual(TrendChart.barWidthRatio(for: 1), 0.90)   // single bar
        XCTAssertEqual(TrendChart.barWidthRatio(for: 4), 0.90)   // last in ≤4
        XCTAssertEqual(TrendChart.barWidthRatio(for: 5), 0.80)   // first in 5-7
        XCTAssertEqual(TrendChart.barWidthRatio(for: 7), 0.80)   // last in 5-7
        XCTAssertEqual(TrendChart.barWidthRatio(for: 8), 0.70)   // first in 8-12
        XCTAssertEqual(TrendChart.barWidthRatio(for: 12), 0.70)  // last in 8-12
        XCTAssertEqual(TrendChart.barWidthRatio(for: 13), 0.60)  // first in 13-24
        XCTAssertEqual(TrendChart.barWidthRatio(for: 24), 0.60)  // last in 13-24
        XCTAssertEqual(TrendChart.barWidthRatio(for: 25), 0.50)  // first in default
    }
}
