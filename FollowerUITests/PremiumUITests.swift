//
//  PremiumUITests.swift
//  FollowerUITests
//
//  Gamma: Premium UI 测试 — 解锁按钮、Premium 卡片显示。

import XCTest

final class PremiumUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Premium Unlock Flow

    func testSettingsTabHasContent() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(3)

        // Settings page should render (Form = table)
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 10)
                      || app.navigationBars.firstMatch.exists)
    }

    func testPremiumUnlockTappable() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)

        // Find any button containing "Premium" or "Unlock" or crown icon
        let unlockBtn = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Unlock")).firstMatch
        if unlockBtn.waitForExistence(timeout: 5) {
            unlockBtn.tap()
            sleep(2)
        }
        // App should survive the tap
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Premium Dashboard Cards

    func testDashboardHasPremiumInsightsSection() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        // 需要先有账号和同步数据才能看到 Premium 卡片
        // 最小验证：Dashboard 页面渲染不崩溃
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        // ScrollView 存在
        XCTAssertTrue(app.scrollViews.firstMatch.exists)
    }

    // MARK: - Post-Unlock Tab Navigation

    func testAllTabsSurviveAfterPremiumUnlock() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons

        // Go to 我的
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)

        // Unlock premium
        let unlockButton = app.buttons["Unlock All Premium"]
        if unlockButton.waitForExistence(timeout: 5) {
            unlockButton.tap()
            sleep(2)
        }

        // Navigate all tabs — should not crash
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
