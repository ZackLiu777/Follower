//
//  ThemeAndLanguageUITests.swift
//  FollowerUITests

import XCTest

final class ThemeAndLanguageUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    func testAllTabsAccessible() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 3)
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(2)
        }
        // 遍历完所有 tab 后不崩溃
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
