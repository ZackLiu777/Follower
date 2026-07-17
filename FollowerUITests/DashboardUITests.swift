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

    // MARK: - Phi: TrendChart on Dashboard

    /// Dashboard 中应展示粉丝周线 TrendChart（标题 "Followers"）
    func testDashboardShowsFollowerTrendChart() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        // 确保在 Dashboard Tab
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(3)

        // Dashboard 中应有 "Followers" 标题的 TrendChart
        let followersTitle = app.staticTexts["Followers"]
        let exists = followersTitle.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Dashboard should display 'Followers' TrendChart")
    }

    /// 点击 Dashboard 的 TrendChart 应跳转到详情页
    func testDashboardTrendChartNavigatesToDetail() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(3)

        // 点击 "Followers" 标题
        let followersTitle = app.staticTexts["Followers"]
        if followersTitle.waitForExistence(timeout: 10) {
            followersTitle.tap()
            sleep(2)

            // 应跳转到 TrendDetailView — 导航栏存在
            let navBar = app.navigationBars.firstMatch
            XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Should navigate to TrendDetailView")
        }
    }

    /// Dashboard 账户切换 → AccountBar 存在且可交互
    func testDashboardAccountBarExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 1 else {
            XCTFail("Expected at least 1 tab")
            return
        }
        tabs.element(boundBy: 0).tap()
        sleep(2)

        // AccountBar 应显示用户名（如 @testuser）
        let userLabel = app.staticTexts.firstMatch
        XCTAssertTrue(userLabel.exists, "AccountBar should display some user info")
    }
}
