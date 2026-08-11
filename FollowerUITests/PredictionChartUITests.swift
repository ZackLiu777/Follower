//
//  PredictionChartUITests.swift
//  FollowerUITests
//
//  预测图表 UI 测试 — 验证贝叶斯预测图表是否真正加载：
//  Dashboard 预测主卡片（跨双列 + 内嵌紧凑区间图 + 一句话摘要）与
//  详情页（Hero 数字 / 三层区间图 / 关键数字行 / 模型说明文字）。
//  注意：摘要行、关键数字、模型说明仅在 hasForecast（预测数据加载成功）
//  时才渲染 —— 它们是图表加载成功的可见信号。
//

import XCTest

/// UI tests for the Bayesian prediction chart — tile presence, chart-data
/// rendering signals (summary / key figures / model caption), back navigation
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

    // MARK: - Dashboard 主卡片

    /// Dashboard 应显示预测主卡片 —— 标题 + 一句话摘要
    /// （摘要 "30d forecast ~…" 仅在预测数据加载成功时渲染 = 图表数据加载信号）
    func testDashboardShowsPredictionTileWithSummary() {
        openDashboard()

        let tile = app.staticTexts["Follower Prediction"]
        scrollTo(tile)
        XCTAssertTrue(tile.exists, "Follower Prediction tile should exist on Dashboard")

        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "30d forecast")
        ).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10),
                      "Prediction tile should show the '30d forecast' summary line — chart data must be loaded")
    }

    // MARK: - 详情页加载

    /// 点击预测主卡片 → 详情页：导航栏标题 + Hero 预测数字卡片
    func testPredictionDetailShowsHeroCard() {
        navigateToPredictionDetail()

        // 导航栏标题（L10n.Premium.followerPrediction）
        let navBar = app.navigationBars["Follower Prediction"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Prediction detail nav bar should exist")

        // Hero 卡片：大号 "~N" 数值 + 副标题
        XCTAssertTrue(app.staticTexts["Predicted Followers Next Month"].exists,
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

    /// 详情页模型说明文字 —— 仅在图表真实渲染（hasForecast）时出现，
    /// 是"预测图表加载正确"的最强可见信号
    func testPredictionDetailShowsModelCaptionWhenChartRendered() {
        navigateToPredictionDetail()

        let caption = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Bayesian negative binomial model")
        ).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10),
                      "Model caption should appear — prediction chart must be rendered (hasForecast)")
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
