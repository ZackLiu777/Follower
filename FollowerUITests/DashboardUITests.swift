//
//  DashboardUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Dashboard — covers launch stability, tab existence, and tab navigation
final class DashboardUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// App 启动 → TabView 应存在，不崩溃
    func testAppDoesNotCrashOnLaunch() {
        // 验证 TabView 存在即可 — 不查找具体 accessibility ID
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    /// 验证所有 Tab 存在 → 至少应有 3 个 Tab
    func testAllTabsExist() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let buttons = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 3, "Should have at least 3 tabs")
    }

    /// 遍历所有 Tab → 切换过程不崩溃
    func testTabNavigationDoesNotCrash() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let buttons = app.tabBars.buttons
        for i in 0..<buttons.count {
            buttons.element(boundBy: i).tap()
            sleep(1)
        }
    }
}
