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

    // MARK: - Dashboard 内容区（v4 重构后结构：Recent Content → Posts → Premium Insights）

    /// Dashboard 应展示核心内容区 — 最近内容 / 查看全部 / Premium Insights
    /// （v4 起 Dashboard 不再内置 "Followers" TrendChart，图表移入 Trends Tab）
    func testDashboardShowsCoreSections() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(3)

        XCTAssertTrue(app.staticTexts["Recent Content"].waitForExistence(timeout: 10),
                      "Dashboard should show Recent Content section")
        XCTAssertTrue(app.staticTexts["View All"].exists,
                      "View All entry should be in Recent Content header row")

        // Premium Insights 区在下方 — 滚动查找
        let premiumHeader = app.staticTexts["Premium Insights"]
        for _ in 0..<5 {
            if premiumHeader.exists { break }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(premiumHeader.exists, "Dashboard should show Premium Insights section")
    }

    /// 点击 Dashboard 的 Premium 预测卡片应跳转到预测详情页
    func testDashboardPremiumTileNavigatesToPredictionDetail() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(3)

        // 滚动到 Follower Prediction 卡片并点击
        let predictionTile = app.staticTexts["Follower Prediction"]
        for _ in 0..<6 {
            if predictionTile.exists { break }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(predictionTile.waitForExistence(timeout: 10),
                      "Follower Prediction tile should exist on Dashboard")
        predictionTile.tap()
        sleep(2)

        // 应跳转到 PredictionDetailView — 导航栏标题存在
        XCTAssertTrue(app.navigationBars["Follower Prediction"].waitForExistence(timeout: 10),
                      "Should navigate to PredictionDetailView")
    }

    /// Dashboard 工具栏应有设置按钮（齿轮，dashboard_settings_button — 位置在导航栏 trailing）
    func testDashboardToolbarSettingsButton() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(2)

        let gear = app.buttons["dashboard_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10),
                      "Settings gear button should exist in Dashboard toolbar")

        // 位于导航栏区域（topBarTrailing）
        XCTAssertTrue(app.navigationBars["Dashboard"].exists,
                      "Dashboard nav bar should exist with the gear button in it")
    }
}
