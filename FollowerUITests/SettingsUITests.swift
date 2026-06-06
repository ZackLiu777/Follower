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
        // Tap the last tab (should be Settings)
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars.firstMatch.exists || app.tables.firstMatch.exists)
    }

    func testAppSurvivesAllTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(2)
        }
    }
}
