//
//  AccountUITests.swift
//  FollowerUITests

import XCTest

final class AccountUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    func testNavigateToSettings() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)
        // Settings page should render
        XCTAssertTrue(app.tables.firstMatch.exists || app.navigationBars.firstMatch.exists)
    }

    func testSettingsHasToolbarButton() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        sleep(2)
        // Toolbar should have the add account button
        let toolbarButtons = app.navigationBars.buttons
        XCTAssertGreaterThanOrEqual(toolbarButtons.count, 1, "Settings toolbar should have buttons")
    }
}
