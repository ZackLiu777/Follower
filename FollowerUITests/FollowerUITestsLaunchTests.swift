//
//  FollowerUITestsLaunchTests.swift
//  FollowerUITests
//
//  Created by Zane Liao on 2026/6/5.
//

import XCTest

/// UI tests for App launch — covers launch screenshot capture
final class FollowerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// 测试准备 — 设置 continueAfterFailure = false
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// App 启动截图 → 使用 UI_TEST 参数启动并保存启动截图
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
