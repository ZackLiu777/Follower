//
//  DashboardUITests.swift
//  FollowerUITests

import XCTest

final class DashboardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    func testAppDoesNotCrashOnLaunch() {
        // 验证 TabView 存在即可 — 不查找具体 accessibility ID
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    func testAllTabsExist() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let buttons = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 3, "Should have at least 3 tabs")
    }

    func testTabNavigationDoesNotCrash() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let buttons = app.tabBars.buttons
        for i in 0..<buttons.count {
            buttons.element(boundBy: i).tap()
            sleep(1)
        }
    }
}
