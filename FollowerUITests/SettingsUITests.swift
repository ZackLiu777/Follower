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

    func testSettingsTabNavigates() {
        let settingsTab = app.buttons["tab_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Verify we landed on Settings — navigation title should exist
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))
    }

    func testSettingsFormExists() {
        app.buttons["tab_settings"].tap()
        // Form should render with sections
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 5))
    }

    func testAppSurvivesSettingsNavigation() {
        app.buttons["tab_settings"].tap()
        sleep(2)
        // Navigate back to Dashboard
        app.buttons["tab_dashboard"].tap()
        XCTAssertTrue(app.buttons["tab_dashboard"].exists)
    }
}
