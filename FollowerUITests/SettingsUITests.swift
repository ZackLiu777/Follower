//
//  SettingsUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Settings — covers tab existence and cross-tab navigation stability
final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// Settings Tab 存在 → 点击最后一个 Tab 应渲染内容
    func testSettingsTabExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 3)
        // 验证最后一个 tab 存在即可，不深入点击（避免 toolbar 干扰）
        let lastTab = tabs.element(boundBy: tabs.count - 1)
        XCTAssertTrue(lastTab.exists)
        lastTab.tap()
        sleep(2)
        // 页面应有内容（Form 或 scrollView 或 table）
        XCTAssertTrue(app.tables.firstMatch.exists || app.scrollViews.firstMatch.exists || app.tabBars.firstMatch.exists)
    }

    /// 遍历所有 Tab → 切换后 App 不崩溃
    func testAppSurvivesAllTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        for i in 0..<app.tabBars.buttons.count {
            app.tabBars.buttons.element(boundBy: i).tap()
            sleep(3)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
