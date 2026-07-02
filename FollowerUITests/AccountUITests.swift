//
//  AccountUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Account settings — covers navigation and toolbar button presence
final class AccountUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// 导航到 Settings Tab → 页面应正常渲染
    func testNavigateToSettings() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)
        // Settings page should render
        XCTAssertTrue(app.tables.firstMatch.exists || app.navigationBars.firstMatch.exists)
    }

    /// Settings 页面 → 导航栏应包含按钮
    func testSettingsHasToolbarButton() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)
        // Toolbar should have the add account button
        let toolbarButtons = app.navigationBars.buttons
        XCTAssertGreaterThanOrEqual(toolbarButtons.count, 1, "Settings toolbar should have buttons")
    }
}
