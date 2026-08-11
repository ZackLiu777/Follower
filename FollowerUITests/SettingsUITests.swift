//
//  SettingsUITests.swift
//  FollowerUITests
//
//  设置页 UI 测试 — 从 Dashboard 工具栏齿轮按钮（dashboard_settings_button）
//  进入设置 sheet：各 Section 加载（试用 / 外观 / 导出 / 隐私 / Premium 主开关）、
//  按钮与开关位置、sheet 关闭返回，以及跨 Tab 稳定性。
//  （v4 重构后设置入口从个人资料弹窗迁移至 Dashboard 工具栏齿轮按钮。）
//

import XCTest

/// UI tests for Settings — gear entry, section rendering, toggle positions,
/// sheet dismissal, and cross-tab stability
final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Helpers

    /// 进入 Dashboard Tab（index 0）
    private func openDashboard() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(2)
    }

    /// 齿轮按钮 → 打开设置页（等待导航栏标题出现）
    private func openSettingsSheet() {
        openDashboard()
        let gear = app.buttons["dashboard_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10),
                      "Gear button should exist in Dashboard toolbar")
        gear.tap()
        sleep(3)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "Settings sheet should open with 'Settings' title")
    }

    // MARK: - Tab 结构

    /// 底栏应有 4 个 Tab（Dashboard / Trends / Decisions / Profile）
    func testTabCountIsFour() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 4)
    }

    // MARK: - 设置入口（按钮位置）

    /// Dashboard 工具栏齿轮按钮 → 打开完整设置页
    func testGearButtonOpensSettingsSheet() {
        openSettingsSheet()
        // 设置页应显示试用状态行
        XCTAssertTrue(app.staticTexts["Trial Active"].waitForExistence(timeout: 10),
                      "Settings should show trial status")
    }

    // MARK: - 设置页各 Section 加载

    /// 外观区：Language / Dark Mode / Theme 行
    func testSettingsAppearanceRowsExist() {
        openSettingsSheet()

        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 10),
                      "Language row should exist")
        XCTAssertTrue(app.staticTexts["Dark Mode"].exists,
                      "Dark Mode row should exist")
        XCTAssertTrue(app.staticTexts["Theme"].exists,
                      "Theme row should exist")
    }

    /// Dark Mode 开关应存在且可切换（切换后 App 不崩溃）
    func testDarkModeToggleIsTappable() {
        openSettingsSheet()

        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10),
                      "Dark Mode toggle should exist")
        toggle.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["Settings"].exists,
                      "App should survive dark mode switch")
    }

    /// 数据导出区：Format / Export Data 行
    func testSettingsExportRowsExist() {
        openSettingsSheet()

        XCTAssertTrue(app.staticTexts["Format"].waitForExistence(timeout: 10),
                      "Format row should exist")
        XCTAssertTrue(app.staticTexts["Export Data"].exists,
                      "Export Data row should exist")
    }

    /// 隐私区：删除所有本地数据按钮应存在
    func testSettingsPrivacyDeleteButtonExists() {
        openSettingsSheet()

        XCTAssertTrue(app.staticTexts["Delete All Local Data"].waitForExistence(timeout: 10),
                      "Delete All Local Data button should exist in privacy section")
    }

    /// Premium 主开关（Unlock All Premium）应存在 — 解锁全部功能的入口
    func testSettingsPremiumMasterToggleExists() {
        openSettingsSheet()

        XCTAssertTrue(app.staticTexts["Unlock All Premium"].waitForExistence(timeout: 10),
                      "Premium master toggle should exist")
    }

    // MARK: - 关闭设置页

    /// 设置页关闭（下滑）→ 回到 Dashboard
    func testSettingsSheetClosesBackToDashboard() {
        openSettingsSheet()

        // sheet 无显式关闭按钮 — 从内容下滑关闭（两次尝试：先 app 再导航栏）
        app.swipeDown(velocity: .fast)
        sleep(2)
        if app.navigationBars["Settings"].exists {
            app.navigationBars["Settings"].swipeDown(velocity: .fast)
            sleep(2)
        }

        XCTAssertTrue(app.tabBars.firstMatch.exists, "Should return to tab bar")
        XCTAssertTrue(app.staticTexts["Recent Content"].waitForExistence(timeout: 10),
                      "Should be back on Dashboard")
    }

    // MARK: - 跨 Tab 稳定性

    /// 遍历所有 Tab → 切换后 App 不崩溃
    func testAppSurvivesAllTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        for i in 0..<app.tabBars.buttons.count {
            app.tabBars.buttons.element(boundBy: i).tap()
            sleep(3)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
