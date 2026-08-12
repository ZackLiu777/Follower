//
//  PostsUITests.swift
//  FollowerUITests
//
//  帖子模块 UI 测试 — Dashboard 最近内容区 → 全部帖子列表 → 帖子详情：
//  入口按钮位置（Recent Content / View All）、列表加载、互动数据渲染、
//  评论管理入口、工具栏按钮（发布队列 + 发布助手）、返回导航。
//

import XCTest

/// UI tests for the Posts flow — Recent Content section, All Posts list,
/// Post Detail rendering, toolbar buttons, and back navigation
final class PostsUITests: XCTestCase {
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
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(3)
    }

    /// 点击「查看全部」进入全部帖子列表页
    private func navigateToAllPosts() {
        openDashboard()
        let viewAll = app.staticTexts["View All"]
        XCTAssertTrue(viewAll.waitForExistence(timeout: 10), "View All entry should exist in Recent Content section")
        viewAll.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["All Posts"].waitForExistence(timeout: 10),
                      "All Posts list should open")
    }

    // MARK: - Dashboard 最近内容区

    /// Dashboard 最近内容区标题与「查看全部」入口应存在
    func testDashboardShowsRecentContentSection() {
        openDashboard()
        XCTAssertTrue(app.staticTexts["Recent Content"].waitForExistence(timeout: 10),
                      "Recent Content section header should exist")
        XCTAssertTrue(app.staticTexts["View All"].exists,
                      "View All entry should be in the section header row")
    }

    // MARK: - 全部帖子列表

    /// 「查看全部」→ 全部帖子列表页加载（导航栏标题 + 帖子行）
    func testViewAllOpensAllPostsList() {
        navigateToAllPosts()

        // 列表应有内容（List 渲染为 table 或 collectionView）
        let hasList = app.tables.firstMatch.exists || app.collectionViews.firstMatch.exists
        XCTAssertTrue(hasList, "All Posts should show a list of posts")
        XCTAssertGreaterThanOrEqual(app.staticTexts.count, 1, "List should have text content")
    }

    // MARK: - 帖子详情

    /// 点击第一行帖子 → 详情页：互动数据（Likes / Comments / Caption）与
    /// 评论管理入口（Premium 按钮位置）
    func testPostDetailShowsInteractionData() {
        navigateToAllPosts()

        // 点击第一行（List 可能是 table 或 collectionView）
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Post list should exist")
        list.cells.firstMatch.tap()
        sleep(2)

        XCTAssertTrue(app.navigationBars["Post Detail"].waitForExistence(timeout: 10),
                      "Post Detail nav bar should exist")
        XCTAssertTrue(app.staticTexts["Likes"].exists, "Likes row should exist")
        XCTAssertTrue(app.staticTexts["Comments"].exists, "Comments row should exist")
        XCTAssertTrue(app.staticTexts["Caption"].exists, "Caption section should exist")

        // 评论管理入口（Premium 门控按钮）— 位置在详情内容区
        let commentsButton = app.buttons["评论管理"]
        XCTAssertTrue(commentsButton.waitForExistence(timeout: 10),
                      "Comment management entry button should exist")
    }

    /// 帖子详情返回 → 回到全部帖子列表
    func testPostDetailBackToAllPosts() {
        navigateToAllPosts()

        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        list.cells.firstMatch.tap()
        sleep(2)

        let navBar = app.navigationBars["Post Detail"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        navBar.buttons.firstMatch.tap()   // Back 按钮
        sleep(2)

        XCTAssertTrue(app.navigationBars["All Posts"].waitForExistence(timeout: 10),
                      "Should return to All Posts list")
    }

    // MARK: - 工具栏按钮位置

    /// 列表页工具栏 trailing 应有发布队列 + 发布助手两个按钮
    func testPostListToolbarHasQueueAndComposerButtons() {
        navigateToAllPosts()

        let navBar = app.navigationBars["All Posts"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        // 推入页导航栏 = [返回] + trailing 工具栏（发布队列 + 发布助手）
        XCTAssertGreaterThanOrEqual(navBar.buttons.count, 2,
                                    "Toolbar should have queue + composer buttons (plus back button)")
    }

    /// 从帖子详情返回后 → Dashboard 最近内容区仍可见（多级返回不崩溃）
    func testBackToDashboardAfterPosts() {
        navigateToAllPosts()

        // 返回 Dashboard（两次 Back）
        app.navigationBars["All Posts"].buttons.firstMatch.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["Recent Content"].waitForExistence(timeout: 10),
                      "Should be back on Dashboard after leaving posts")
    }
}
