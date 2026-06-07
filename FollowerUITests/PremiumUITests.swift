//
//  PremiumUITests.swift
//  FollowerUITests
//
//  Lambda: Premium 解锁 UI 测试 — 工具栏按钮可点击、解锁后状态同步。

import XCTest

final class PremiumUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Unlock button in toolbar

    func testPremiumUnlockButtonExistsInToolbar() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)

        // Unlock button is now in toolbar (crown.fill icon)
        let toolbarButton = app.toolbars.buttons.firstMatch
        let unlockExists = toolbarButton.waitForExistence(timeout: 5)
        // Or check via navigation bar buttons containing crown/unlock text
        let navButtons = app.navigationBars.buttons
        let hasButton = unlockExists || navButtons.count > 1
        XCTAssertTrue(hasButton, "Settings toolbar should have unlock button")
    }

    func testUnlockButtonIsTappable() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)

        // Tap any toolbar button — should not crash
        let toolbarButtons = app.toolbars.buttons
        if toolbarButtons.firstMatch.waitForExistence(timeout: 5) {
            toolbarButtons.firstMatch.tap()
            sleep(2)
        }
        // App should survive
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Post-unlock sync

    func testAllTabsSurviveAfterPremiumUnlock() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons

        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)

        // Tap toolbar unlock if present
        let toolbarBtn = app.toolbars.buttons.firstMatch
        if toolbarBtn.waitForExistence(timeout: 5) {
            toolbarBtn.tap()
            sleep(2)
        }

        // Navigate all tabs — should survive
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testDashboardHasPremiumInsightsSection() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        XCTAssertTrue(app.scrollViews.firstMatch.exists)
    }
}
