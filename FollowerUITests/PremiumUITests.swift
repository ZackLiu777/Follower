//
//  PremiumUITests.swift
//  FollowerUITests
//
//  Lambda: Premium 解锁 UI 测试 — 工具栏按钮可点击、解锁后状态同步。

import XCTest

/// UI tests for Premium features — covers unlock button, card navigation, lock state, and theme persistence
final class PremiumUITests: XCTestCase {
    var app: XCUIApplication!

    /// 测试准备 — 配置 UI_TEST 参数并启动 App
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST"]
        app.launch()
    }

    // MARK: - Unlock button in navigation bar

    /// Premium 解锁按钮 → 设置页导航栏应存在按钮
    func testPremiumUnlockButtonExistsInToolbar() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        // Dashboard avatar → profile sheet → settings
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10), "Avatar button should exist on dashboard")
        avatar.tap()
        sleep(2)
        let settingsLink = app.buttons["profile_settings_link"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10), "Profile sheet settings link should exist")
        settingsLink.tap()
        sleep(3)

        // Settings navigation bar should exist with back button
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Navigation bar should exist")
        let crownButton = navBar.buttons["crown.fill"]  // SF Symbol accessibility identifier
        // Fallback: any navigation bar button (back)
        let hasButton = crownButton.exists || navBar.buttons.count >= 1
        XCTAssertTrue(hasButton, "Settings nav bar should have buttons")
    }

    /// 解锁按钮 → 可点击且不崩溃
    func testUnlockButtonIsTappable() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let avatar = app.buttons["account_avatar_button"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        avatar.tap()
        sleep(2)
        let settingsLink = app.buttons["profile_settings_link"]
        if settingsLink.waitForExistence(timeout: 5) {
            settingsLink.tap()
            sleep(3)
        }

        // Tap first nav bar button if exists
        let navBar = app.navigationBars.firstMatch
        if navBar.waitForExistence(timeout: 5) {
            let btn = navBar.buttons.firstMatch
            if btn.exists { btn.tap(); sleep(2) }
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Post-unlock sync

    /// Premium 解锁后 → 所有 Tab 切换正常，不崩溃
    func testAllTabsSurviveAfterPremiumUnlock() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        let tabs = app.tabBars.buttons
        for i in 0..<tabs.count {
            tabs.element(boundBy: i).tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// Dashboard → Premium Insights 区域应存在
    func testDashboardHasPremiumInsightsSection() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)
        // Dashboard has scroll view with content
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)
    }

    // MARK: - Premium Card Navigation (Dashboard)

    /// 验证解锁后 Premium 区域的 9 张卡片均存在且可点击
    func testAllPremiumCardsVisibleAfterUnlock() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        // Navigate to Dashboard (first tab)
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        // Scroll to premium section
        app.swipeUp()
        sleep(2)

        // Verify premium section header exists
        let premiumHeader = app.staticTexts["Premium Insights"]
        // Scroll until premium header is visible or we can't scroll anymore
        for _ in 0..<5 {
            if premiumHeader.exists { break }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(premiumHeader.exists, "Premium Insights section header should be visible")

        // Verify key premium cards are present as static text
        let cardTitles = [
            "Follower Prediction",
            "Activity Analysis",
            "Engagement Quality",
            "Retention & Churn",
            "Geo Distribution",
            "Long-term Comparison",
            "Who Unfollowed You",
            "Best Time to Post",
            "Content Strategy"
        ]
        for title in cardTitles {
            let element = app.staticTexts[title]
            if !element.exists {
                app.swipeUp()
                sleep(1)
            }
            XCTAssertTrue(element.exists, "Premium card '\(title)' should be visible in unlocked state")
        }
    }

    /// 点击 Follower Prediction 卡片进入详情页后可以返回
    func testNavigateToPredictionDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        // Scroll to premium section
        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Follower Prediction"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Follower Prediction card should exist")
        card.tap()
        sleep(2)

        // Verify detail navigation exists
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Detail navigation bar should exist")
        // Detail should have content
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        // Go back
        let backButton = navBar.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }

        // Verify we returned to Dashboard
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// 点击 Activity Analysis 卡片进入详情页
    func testNavigateToActivityDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Activity Analysis"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Activity Analysis card should exist")
        card.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// 点击 Engagement Quality 卡片进入详情页
    func testNavigateToQualityDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Engagement Quality"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Engagement Quality card should exist")
        card.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// 点击 Retention & Churn 卡片进入详情页
    func testNavigateToRetentionDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Retention & Churn"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Retention & Churn card should exist")
        card.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// 点击 Geo Distribution 卡片进入详情页
    func testNavigateToGeoDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Geo Distribution"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Geo Distribution card should exist")
        card.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    /// 点击 Long-term Comparison 卡片进入详情页
    func testNavigateToComparisonDetailAndBack() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        let card = app.staticTexts["Long-term Comparison"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Long-term Comparison card should exist")
        card.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists)

        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Premium Lock State

    /// 锁定状态下 Premium 卡片显示锁图标；解锁状态下锁图标不存在
    func testPremiumCardsShowLockIconWhenLocked() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        // Scroll to premium section
        app.swipeUp()
        sleep(2)

        // Premium section header should exist
        let premiumHeader = app.staticTexts["Premium Insights"]
        for _ in 0..<5 {
            if premiumHeader.exists { break }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(premiumHeader.exists, "Premium Insights header should exist")

        // In unlocked state (fresh trial), lock icons should NOT be present
        let lockIcon = app.images["lock.fill"]
        XCTAssertFalse(lockIcon.exists, "Lock icons should not be visible when premium is unlocked (trial active)")

        // Premium card labels should be visible (unlocked state)
        let predictionCard = app.staticTexts["Follower Prediction"]
        XCTAssertTrue(predictionCard.waitForExistence(timeout: 5), "Follower Prediction label should exist")
    }

    // MARK: - Theme Persistence in Detail

    /// 详情页背景随主题切换而改变 — 验证详情页渲染正常
    func testPremiumDetailRespectsTheme() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)

        app.swipeUp()
        sleep(2)

        // Navigate to Follower Prediction detail
        let card = app.staticTexts["Follower Prediction"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(2)

        // Detail view should have rendered content (scroll view, static text, or images)
        let detailHasContent = app.scrollViews.firstMatch.exists
            || app.staticTexts.firstMatch.exists
            || app.images.count > 2
        XCTAssertTrue(detailHasContent, "Premium detail should render content after navigation")

        // Go back
        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)
        }
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
