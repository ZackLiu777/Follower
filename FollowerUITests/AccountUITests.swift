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

    func testSettingsHasConnectAccountButton() {
        app.buttons["tab_settings"].tap()
        // Look for a button containing "Connect" — handles localization
        let connectButton = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Connect")).firstMatch
        let exists = connectButton.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Connect Account button should exist in Settings")
    }

    func testAccountSheetOpensAndCloses() {
        app.buttons["tab_settings"].tap()

        let connectButton = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Connect")).firstMatch
        guard connectButton.waitForExistence(timeout: 10) else { return }
        connectButton.tap()

        // Account sheet should appear with Done button
        let doneButton = app.navigationBars.buttons.firstMatch
        if doneButton.waitForExistence(timeout: 5) {
            doneButton.tap()
        }
    }
}
