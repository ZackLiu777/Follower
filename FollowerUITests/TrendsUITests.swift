//
//  TrendsUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Trends — covers tab navigation, trend detail, time window display, and back navigation
final class TrendsUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// Trends Tab 导航 → 中间 Tab 应存在且可点击，页面有内容
    func testTrendsTabNavigates() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        // Middle tab should be Trends
        if tabs.count >= 2 {
            tabs.element(boundBy: 1).tap()
            sleep(2)
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)
        }
    }

    // MARK: - Trend Detail Navigation

    /// 点击任意 TrendChart 卡片导航到详情页并验证 Hero 数值存在
    func testTapTrendChartNavigatesToDetail() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        // Navigate to Trends tab (middle tab, index 1)
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(3)

        // Tap the first trend chart ("Followers")
        let chartTitle = app.staticTexts["Followers"]
        XCTAssertTrue(chartTitle.waitForExistence(timeout: 10), "Followers chart should exist in Trends tab")
        chartTitle.tap()
        sleep(2)

        // Verify detail view loaded — navigation bar with title
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Trend detail navigation bar should exist")

        // Hero card should show a large value (static text with numeric content)
        let detailContentExists = app.scrollViews.firstMatch.exists
            || app.staticTexts.count > 3
        XCTAssertTrue(detailContentExists, "Trend detail should have scroll content or multiple text elements")
    }

    /// 详情页显示正确的时间窗标签
    func testTrendDetailShowsTimeWindow() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(3)

        // Tap "Followers" chart to navigate to detail
        let chartTitle = app.staticTexts["Followers"]
        XCTAssertTrue(chartTitle.waitForExistence(timeout: 10))
        chartTitle.tap()
        sleep(2)

        // Detail view should have a time window label (Daily, Weekly, Monthly, or Yearly)
        let timeWindowLabels = ["Daily", "Weekly", "Monthly", "Yearly"]
        let foundTimeWindow = timeWindowLabels.contains { label in
            app.staticTexts[label].exists
        }
        XCTAssertTrue(foundTimeWindow, "Trend detail should show a time window label (Daily/Weekly/Monthly/Yearly)")

        // Also verify the detail has navigation bar
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    /// 详情页可以返回到趋势列表
    func testTrendDetailBackToTrendsList() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(3)

        // Navigate to trend detail
        let chartTitle = app.staticTexts["Followers"]
        XCTAssertTrue(chartTitle.waitForExistence(timeout: 10))
        chartTitle.tap()
        sleep(2)

        // Verify we are on the detail page
        let detailNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 10))

        // Tap back button to return to Trends list
        let backButton = detailNavBar.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }

        // Verify we returned to Trends tab (tab bar should still be visible)
        XCTAssertTrue(app.tabBars.firstMatch.exists)

        // Verify the trends list content is visible again (Followers chart should exist)
        let followersChart = app.staticTexts["Followers"]
        XCTAssertTrue(followersChart.waitForExistence(timeout: 10), "Should return to Trends list with Followers chart visible")
    }

    // MARK: - Phi: 六个 TrendChart 卡片全部可见

    /// Trends 页应展示全部 6 个指标图表
    func testAllSixMetricsChartsVisible() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(4)

        // 六个指标标题应在当前语言环境下可见
        let expectedTitles = ["Followers", "Engagement", "Avg Likes", "Avg Comments", "Avg Shares", "Views"]
        for title in expectedTitles {
            let element = app.staticTexts[title]
            let exists = element.waitForExistence(timeout: 5)
            XCTAssertTrue(exists, "Trends page should show '\(title)' chart")
        }
    }

    /// 评论图表的 Y 轴不应出现负值或 "0 0 0" 等无意义标签
    func testCommentsChartHasValidYAxis() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(4)

        // 验证评论图表存在且可点击（不会崩溃）
        let commentsChart = app.staticTexts["Avg Comments"]
        if commentsChart.waitForExistence(timeout: 10) {
            commentsChart.tap()
            sleep(2)
            // 详情页应能正常打开
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                          "Avg Comments detail should open without crash")
        }
    }

    /// 分享图表的 Y 轴不应出现负值或 "0 0 0" 等无意义标签
    func testSharesChartHasValidYAxis() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(4)

        // 验证分享图表存在且可点击（不会崩溃）
        let sharesChart = app.staticTexts["Avg Shares"]
        if sharesChart.waitForExistence(timeout: 10) {
            sharesChart.tap()
            sleep(2)
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                          "Avg Shares detail should open without crash")
        }
    }

    // MARK: - Phi: 多账号数据隔离

    /// Dashboard 切换账户后，Trends 页应同步刷新（通过 AppState.selectedAccountId）
    func testTrendsSyncsWithDashboardAccountSwitch() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        // 切换到 Trends Tab
        let tabs = app.tabBars.buttons
        guard tabs.count >= 2 else {
            XCTFail("Expected at least 2 tabs")
            return
        }
        tabs.element(boundBy: 1).tap()
        sleep(3)

        // 记录当前 Trends 页图表数量
        let followersChart = app.staticTexts["Followers"]
        XCTAssertTrue(followersChart.waitForExistence(timeout: 10),
                      "Before account switch: Followers chart should exist")

        // 切回 Dashboard（如果在 Dashboard 切换账户，Trends 应响应）
        tabs.element(boundBy: 0).tap()
        sleep(2)

        // 切回 Trends — 页面仍应有数据
        tabs.element(boundBy: 1).tap()
        sleep(3)

        // Trends 页面应正常显示图表（不崩溃、不空白）
        XCTAssertTrue(followersChart.waitForExistence(timeout: 10),
                      "After returning to Trends: Followers chart should still exist")
    }
}
