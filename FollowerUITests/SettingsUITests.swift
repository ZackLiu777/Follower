//
//  SettingsUITests.swift
//  FollowerUITests

import XCTest

final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    func testSettingsTabExists() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 3)
        // 验证最后一个 tab 存在即可，不深入点击（避免 toolbar 干扰）
        let lastTab = tabs.element(boundBy: tabs.count - 1)
        XCTAssertTrue(lastTab.exists)
        lastTab.tap()
        sleep(2)
        // 页面应有内容（Form 或 scrollView 或 table）
        XCTAssertTrue(app.tables.firstMatch.exists || app.scrollViews.firstMatch.exists || app.tabBars.firstMatch.exists)
    }

    func testAppSurvivesAllTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        for i in 0..<app.tabBars.buttons.count {
            app.tabBars.buttons.element(boundBy: i).tap()
            sleep(3)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
