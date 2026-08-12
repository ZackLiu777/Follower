//
//  AccountUITests.swift
//  FollowerUITests
//
//  账号 UI 测试 — Profile Tab（第 4 个 Tab）：
//  个人资料头部（@用户名 + 平台）、账号行、连接新账号入口、
//  活动状态区块，以及 Tab 切换后的状态保持。
//  （v4 重构后个人资料从 Dashboard 头像弹窗迁移为独立 Tab，
//   原 account_avatar_button / profile_settings_link 标识已不存在。）
//

import XCTest

/// UI tests for Account — Profile tab header, account row, connect entry,
/// activity status, and cross-tab stability
final class AccountUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Helpers

    /// 进入 Profile Tab（第 4 个 Tab，index 3）
    private func openProfileTab() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 4 else {
            XCTFail("Expected at least 4 tabs (Dashboard/Trends/Decisions/Profile)")
            return
        }
        tabs.element(boundBy: 3).tap()
        sleep(3)
    }

    /// Profile Tab → 个人资料头部（@用户名 + Instagram 平台）
    func testProfileTabShowsAccountHeader() {
        openProfileTab()

        // 头部显示 @用户名（mock 账号 test.user → "@test.user"）
        let userLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "@")
        ).firstMatch
        XCTAssertTrue(userLabel.waitForExistence(timeout: 10),
                      "Profile header should show @username")
        XCTAssertTrue(app.staticTexts["Instagram"].exists,
                      "Profile header should show Instagram platform label")
    }

    /// Profile Tab → 账号列表应显示账号行（可切换）
    func testProfileTabShowsAccountRow() {
        openProfileTab()

        let accountRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "test.user")
        ).firstMatch
        XCTAssertTrue(accountRow.waitForExistence(timeout: 10),
                      "Account list should show test.user row")
    }

    /// Profile Tab → 连接新账号入口按钮应存在
    func testProfileTabShowsConnectAccountButton() {
        openProfileTab()

        let connectButton = app.buttons["Connect New Account"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 10),
                      "Connect New Account button should exist")
    }

    /// Profile Tab → 活动状态区块
    func testProfileTabShowsActivityStatus() {
        openProfileTab()

        XCTAssertTrue(app.staticTexts["Activity Status"].waitForExistence(timeout: 10),
                      "Activity Status section should exist")
    }

    /// Profile Tab → 切换其他 Tab 再返回，页面状态保持不崩溃
    func testProfileTabSurvivesTabSwitch() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        guard tabs.count >= 4 else {
            XCTFail("Expected at least 4 tabs")
            return
        }
        tabs.element(boundBy: 3).tap()
        sleep(2)
        tabs.element(boundBy: 0).tap()
        sleep(2)
        tabs.element(boundBy: 3).tap()
        sleep(2)

        XCTAssertTrue(app.buttons["Connect New Account"].waitForExistence(timeout: 10),
                      "Profile tab should still show account content after tab switch")
    }
}
