//
//  FollowerUITests.swift
//  FollowerUITests
//
//  Created by Zane Liao on 2026/6/5.
//

import XCTest

/// UI tests for Follower — covers example test and launch performance
final class FollowerUITests: XCTestCase {

    /// 测试准备 — 设置 continueAfterFailure = false
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// 测试清理 — 调用 super.tearDownWithError()
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// 示例测试 → 使用 UI_TEST 参数启动 App 并验证基本功能
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// 启动性能测试 → 测量 App 冷启动耗时
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
