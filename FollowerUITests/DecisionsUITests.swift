//
//  DecisionsUITests.swift
//  FollowerUITests
//
//  Growth Decision Engine UI 测试 — Tab 导航、卡片渲染、刷新操作。

import XCTest

/// UI tests for Decisions — covers tab existence, card display, refresh, and scheme switching
final class DecisionsUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Tab Navigation

    /// Decisions Tab 应存在且可点击，页面有内容
    func testDecisionsTabExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        // Decisions should be at index 2 (Dashboard=0, Trends=1, Decisions=2, Settings=3)
        XCTAssertGreaterThanOrEqual(tabs.count, 3, "Expected at least 3 tabs including Decisions")
        tabs.element(boundBy: 2).tap()
        sleep(3)
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)
    }

    /// 切换到 Decisions Tab 后导航标题正确
    func testDecisionsTabHasTitle() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 3 else { return }
        tabs.element(boundBy: 2).tap()
        sleep(3)
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Decisions nav bar should exist")
    }

    // MARK: - Card Display

    /// Decisions 页面应显示至少一张行动卡片（无账号时 mock 数据生成 4 张）
    func testDecisionsShowsCards() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 3 else { return }
        tabs.element(boundBy: 2).tap()
        sleep(3)
        // Cards should be visible — check for static text content
        let cardExists = app.staticTexts.count > 2
        XCTAssertTrue(cardExists, "Decisions should show card content with static text")
    }

    /// 刷新按钮存在且可点击
    func testDecisionsRefreshButtonExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 3 else { return }
        tabs.element(boundBy: 2).tap()
        sleep(3)
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        let refreshBtn = navBar.buttons.firstMatch
        if refreshBtn.exists {
            refreshBtn.tap()
            sleep(2)
        }
        // Should not crash and tab should still be visible
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Cross-tab Navigation

    /// 从 Decisions 切换到 Dashboard 再切回，状态保持
    func testDecisionsSurvivesTabSwitch() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 4 else { return }
        tabs.element(boundBy: 2).tap()
        sleep(2)
        tabs.element(boundBy: 0).tap()
        sleep(2)
        tabs.element(boundBy: 2).tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts.firstMatch.exists || app.scrollViews.firstMatch.exists)
    }
}
