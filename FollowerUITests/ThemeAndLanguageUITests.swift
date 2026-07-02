//
//  ThemeAndLanguageUITests.swift
//  FollowerUITests

import XCTest

/// UI tests for Theme & Language — covers app launch and all tabs accessibility
final class ThemeAndLanguageUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    /// App 启动 → TabView 应存在
    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    /// 所有 Tab 可访问 → 遍历切换不崩溃
    func testAllTabsAccessible() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 3)
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(3)
        }
        // 遍历完不崩溃
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
