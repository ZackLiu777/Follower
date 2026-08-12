//
//  PredictionChartUITests.swift
//  FollowerUITests
//
//  预测图表 UI 测试 — 验证预测图表是否真正加载：
//  Dashboard 预测 tile（图标 + 标题入口，v0.16 起不再内嵌图表/摘要文字）与
//  详情页（Hero 数字 / 三层区间图 / 关键数字行）。
//  注意：关键数字仅在 hasForecast（预测数据加载成功）时才渲染 —
//  它是图表加载成功的可见信号；模型名称文字已按要求移除并加回归断言。
//

import XCTest

/// UI tests for the prediction chart — tile presence, chart-data
/// rendering signals (hero card / key figures), back navigation
final class PredictionChartUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Helpers

    /// 进入 Dashboard Tab（index 0）
    private func openDashboard() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)
    }

    /// 滚动直到元素可见（最多 maxSwipes 次上滑）
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes {
            if element.exists { return }
            app.swipeUp()
            sleep(1)
        }
    }

    /// 滚动到预测主卡片并点击，进入详情页
    private func navigateToPredictionDetail() {
        openDashboard()
        let tile = app.staticTexts["Follower Prediction"]
        scrollTo(tile)
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Follower Prediction tile should exist on Dashboard")
        tile.tap()
        sleep(2)
    }

    // MARK: - Dashboard 预测 tile

    /// Dashboard 预测 tile —— 只保留图标 + 标题入口，不直接展示图表或数据文字
    /// （v0.16：内嵌区间图与 "30d forecast" 摘要已移入详情页，此处回归断言其不出现）
    func testDashboardPredictionTileShowsNoChartData() {
        openDashboard()

        let tile = app.staticTexts["Follower Prediction"]
        scrollTo(tile)
        XCTAssertTrue(tile.exists, "Follower Prediction tile should exist on Dashboard")

        // 卡片不再内嵌图表摘要文字（"30d forecast ~…" 已移除）
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "30d forecast")
        ).firstMatch
        sleep(2)
        XCTAssertFalse(summary.exists, "Dashboard tile should NOT show forecast summary text")
    }

    // MARK: - 详情页加载

    /// 点击预测主卡片 → 详情页：导航栏标题 + Hero 预测数字卡片
    func testPredictionDetailShowsHeroCard() {
        navigateToPredictionDetail()

        // 导航栏标题（L10n.Premium.followerPrediction）
        let navBar = app.navigationBars["Follower Prediction"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Prediction detail nav bar should exist")

        // Hero 卡片：大号 "~N" 数值 + 副标题（本地化 key premium.predictedFollowersNext）
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Predicted Followers")
        ).firstMatch.exists,
                      "Hero card subtitle should exist")
        let heroValue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "~")
        ).firstMatch
        XCTAssertTrue(heroValue.waitForExistence(timeout: 5),
                      "Hero card should show ~N predicted value")
    }

    /// 详情页关键数字行 —— 80% 区间 + 增长概率（仅 hasForecast 渲染）
    func testPredictionDetailShowsKeyFigures() {
        navigateToPredictionDetail()

        XCTAssertTrue(app.staticTexts["80% Likely Range"].waitForExistence(timeout: 10),
                      "Key figures row should show 80% Likely Range")
        XCTAssertTrue(app.staticTexts["Growth Probability"].exists,
                      "Key figures row should show Growth Probability")

        // 区间值应为数字区间文本（如 "8,123 – 8,456"）
        let rangeValue = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "–")
        ).firstMatch
        XCTAssertTrue(rangeValue.exists, "80% range should show a numeric interval")
    }

    /// 详情页不出现模型名称 —— 关键数字存在 = 图表已渲染（hasForecast），
    /// 同时模型名称（"Bayesian …"）不得出现（v0.16 已移除）
    func testPredictionDetailShowsNoModelName() {
        navigateToPredictionDetail()

        // 关键数字行存在 → 图表数据已加载（替代原 caption 作为渲染信号）
        XCTAssertTrue(app.staticTexts["80% Likely Range"].waitForExistence(timeout: 10),
                      "Key figures row should exist — chart data loaded")

        // 模型名称不得出现在详情页
        let caption = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Bayesian")
        ).firstMatch
        sleep(2)
        XCTAssertFalse(caption.exists, "Detail page should NOT show the model name")
    }

    // MARK: - 返回导航

    /// 详情页返回 → Dashboard 仍正常（标题/摘要区可见）
    func testPredictionDetailBackToDashboard() {
        navigateToPredictionDetail()

        let navBar = app.navigationBars["Follower Prediction"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        navBar.buttons.firstMatch.tap()   // Back 按钮
        sleep(2)

        XCTAssertTrue(app.tabBars.firstMatch.exists, "Should return to tab bar")
        XCTAssertTrue(app.staticTexts["Recent Content"].waitForExistence(timeout: 10),
                      "Should be back on Dashboard with content visible")
    }
}
