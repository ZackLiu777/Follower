//
//  TrendsUITests.swift
//  FollowerUITests

import XCTest

final class TrendsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    func testTrendsTabNavigates() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        // Middle tab should be Trends
        if tabs.count >= 2 {
            tabs.element(boundBy: 1).tap()
            sleep(2)
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)
        }
    }
}
