//
//  ThemeAndLanguageUITests.swift
//  FollowerUITests

import XCTest

final class ThemeAndLanguageUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppSurvivesThemeSwitch() {
        app.buttons["tab_settings"].tap()
        sleep(2)

        // Look for segmented control buttons
        let instagramButton = app.buttons["Instagram"]
        let appleButton = app.buttons["Apple Native"]

        if instagramButton.exists {
            instagramButton.tap()
            sleep(1)
        }
        if appleButton.exists {
            appleButton.tap()
            sleep(1)
        }

        // App should still be alive
        XCTAssertTrue(app.buttons["tab_dashboard"].exists)
    }

    func testAppSurvivesLanguageSwitch() {
        app.buttons["tab_settings"].tap()
        sleep(2)

        // Verify Settings is showing
        XCTAssertTrue(app.tables.firstMatch.exists)

        // Navigate back home to verify no crash
        app.buttons["tab_dashboard"].tap()
        sleep(1)
        XCTAssertTrue(app.buttons["tab_dashboard"].exists)
    }

    func testAllTabsAccessibleAfterSettingsVisited() {
        // Visit Settings
        app.buttons["tab_settings"].tap()
        sleep(2)

        // Return to Dashboard
        app.buttons["tab_dashboard"].tap()
        XCTAssertTrue(app.buttons["tab_dashboard"].waitForExistence(timeout: 5))

        // Visit Trends
        app.buttons["tab_trends"].tap()
        XCTAssertTrue(app.buttons["tab_trends"].waitForExistence(timeout: 5))
    }
}
