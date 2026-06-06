//
//  DashboardUITests.swift
//  FollowerUITests

import XCTest

final class DashboardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testDashboardTabExists() {
        let tab = app.buttons["tab_dashboard"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Dashboard tab should exist")
    }

    func testTrendsTabExists() {
        XCTAssertTrue(app.buttons["tab_trends"].waitForExistence(timeout: 5))
    }

    func testSettingsTabExists() {
        XCTAssertTrue(app.buttons["tab_settings"].waitForExistence(timeout: 5))
    }

    func testTabNavigationCyclesAllTabs() {
        let tabs = ["tab_dashboard", "tab_trends", "tab_settings"]
        for id in tabs {
            let button = app.buttons[id]
            XCTAssertTrue(button.exists || button.waitForExistence(timeout: 3), "Tab \(id) should exist")
            button.tap()
            sleep(1)
        }
    }

    func testAppDoesNotCrashOnLaunch() {
        XCTAssertTrue(app.buttons["tab_dashboard"].waitForExistence(timeout: 10))
    }
}
