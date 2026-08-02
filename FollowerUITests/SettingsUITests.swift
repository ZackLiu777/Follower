//
//  SettingsUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Settings (via profile sheet) — covers avatar entry and cross-tab navigation stability
final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// 底栏应包含 3 个 Tab（设置已迁移到账号弹窗）
    func testTabCountIsThree() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 3)
    }

    /// 仪表盘右上角账号头像 → 点击弹出个人资料弹窗
    func testAvatarOpensProfileSheet() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "Avatar button should exist on dashboard")
        avatar.tap()
        sleep(2)
        // 弹窗应有透明关闭按钮（✕）
        XCTAssertTrue(app.buttons["profile_close_button"].waitForExistence(timeout: 10),
                      "Profile sheet close button should exist")
        // 弹窗应有「设置」入口
        XCTAssertTrue(app.buttons["profile_settings_link"].exists,
                      "Profile sheet should have settings entry")
    }

    /// 头像 → 弹窗 → 点「设置」→ 进入完整设置页
    func testProfileSettingsLinkOpensSettings() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        avatar.tap()
        sleep(2)
        let settingsLink = app.buttons["profile_settings_link"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10))
        settingsLink.tap()
        sleep(2)
        // 设置页应有内容（Form）
        XCTAssertTrue(app.tables.firstMatch.exists || app.navigationBars.firstMatch.exists)
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
