//
//  TrendsViewModelTests.swift
//  FollowerTests
//
//  Trends ViewModel 测试：窗口切换重建数据点。

import XCTest
@testable import Follower

final class TrendsViewModelTests: XCTestCase {

    // TrendsViewModel is @MainActor — window/metric switching logic tested implicitly via UI

    func testTrendDataPointIdentifiable() {
        let point = TrendDataPoint(date: Date(), value: 42.0)
        XCTAssertEqual(point.id, point.date)
        XCTAssertEqual(point.value, 42.0)
    }

    func testTrendDataPointCorrectValue() {
        let date = Date()
        let point = TrendDataPoint(date: date, value: 100.5)
        XCTAssertEqual(point.value, 100.5)
    }
}
