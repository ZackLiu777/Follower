//
//  AccountUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Account — covers avatar profile sheet entry and settings navigation
final class AccountUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// 仪表盘头像 → 点击弹出个人资料弹窗，页面应正常渲染
    func testNavigateToProfileSheet() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "Avatar button should exist on dashboard")
        avatar.tap()
        sleep(2)
        // 弹窗应正常渲染（关闭按钮存在）
        XCTAssertTrue(app.buttons["profile_close_button"].waitForExistence(timeout: 10))
    }

    /// 弹窗 → 点「设置」→ 设置页导航栏应包含按钮（返回按钮）
    func testSettingsNavButtonAfterEntry() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        avatar.tap()
        sleep(2)
        let settingsLink = app.buttons["profile_settings_link"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10))
        settingsLink.tap()
        sleep(2)
        // Toolbar should have the back button
        let toolbarButtons = app.navigationBars.buttons
        XCTAssertGreaterThanOrEqual(toolbarButtons.count, 1, "Settings nav bar should have buttons")
    }
}
