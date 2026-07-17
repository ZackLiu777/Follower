//
//  AppStateTests.swift
//  FollowerTests
//
//  Phi: AppState 全局账户选择单例真源 — 验证 selectedAccountId 初始状态、读写、跨 Tab 同步。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for AppState — covers selectedAccountId as single source of truth
struct AppStateTests {

    // MARK: - selectedAccountId 初始状态

    /// 初始化时 selectedAccountId 应为 nil（未选中任何账户）
    @MainActor
    @Test
    func testSelectedAccountIdDefaultsToNil() {
        let appState = AppState(databaseManager: DatabaseManager.shared)
        #expect(appState.selectedAccountId == nil)
    }

    /// selectedAccountId 可被赋值并读取
    @MainActor
    @Test
    func testSelectedAccountIdReadWrite() {
        let appState = AppState(databaseManager: DatabaseManager.shared)
        appState.selectedAccountId = 42
        #expect(appState.selectedAccountId == 42)
    }

    /// selectedAccountId 可被重置为 nil
    @MainActor
    @Test
    func testSelectedAccountIdResetToNil() {
        let appState = AppState(databaseManager: DatabaseManager.shared)
        appState.selectedAccountId = 100
        #expect(appState.selectedAccountId == 100)
        appState.selectedAccountId = nil
        #expect(appState.selectedAccountId == nil)
    }

    // MARK: - selectedAccountId 与 syncState 共存

    /// selectedAccountId 独立于 syncState — 修改 one 不影响 other
    @MainActor
    @Test
    func testSelectedAccountIdIndependentOfSyncState() {
        let appState = AppState(databaseManager: DatabaseManager.shared)
        #expect(appState.syncState == .noAccount)
        #expect(appState.selectedAccountId == nil)

        appState.selectedAccountId = 1
        #expect(appState.selectedAccountId == 1)
        #expect(appState.syncState == .noAccount, "syncState should not be affected by selectedAccountId change")
    }
}
