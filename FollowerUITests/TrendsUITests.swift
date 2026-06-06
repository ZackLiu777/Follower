//
//  TrendsUITests.swift
//  FollowerUITests

import XCTest

final class TrendsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTrendsTabNavigates() {
        let trendsTab = app.buttons["tab_trends"]
        XCTAssertTrue(trendsTab.waitForExistence(timeout: 5))
        trendsTab.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    func testTrendsPageHasContent() {
        app.buttons["tab_trends"].tap()
        sleep(2)
        // Page should have some content (chart or empty state)
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)
    }
}
