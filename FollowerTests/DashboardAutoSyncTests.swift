//
//  DashboardAutoSyncTests.swift
//  FollowerTests
//
//  v0.15.1: 测试账号自动补同步判定（needsAutoSyncForTestAccount）单元测试。
//  背景：旧版（8/7 前）创建的测试账号只有静态快照（< 30 天），
//  无法满足贝叶斯冷启动线 → 打开 app 时自动补一次全量 mock 同步。
//  真实账号（isTest=false）永不自动 sync（保护 API 配额）。
//

import Testing
import Foundation
@testable import Follower

struct DashboardAutoSyncTests {

    /// isTest 账号 + 90 天快照不足冷启动线 + 未在同步 → 需要补同步
    @MainActor
    @Test
    func testTestAccountWithFewDaysNeedsSync() {
        #expect(DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 0, isSyncing: false))
        #expect(DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 10, isSyncing: false))
        #expect(DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 29, isSyncing: false))
    }

    /// isTest 账号但快照已满足冷启动线（≥ minRows=30）→ 不补同步
    @MainActor
    @Test
    func testTestAccountWithEnoughDaysSkipsSync() {
        #expect(!DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 30, isSyncing: false))
        #expect(!DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 90, isSyncing: false))
    }

    /// 真实账号（isTest=false）即使数据不足也不自动 sync — 保护 API 配额
    @MainActor
    @Test
    func testRealAccountNeverAutoSyncs() {
        #expect(!DashboardViewModel.needsAutoSyncForTestAccount(isTest: false, snapshotDays: 0, isSyncing: false))
        #expect(!DashboardViewModel.needsAutoSyncForTestAccount(isTest: false, snapshotDays: 10, isSyncing: false))
    }

    /// 正在同步中 → 不重复触发（防重入/递归）
    @MainActor
    @Test
    func testSyncingSuppressesAutoSync() {
        #expect(!DashboardViewModel.needsAutoSyncForTestAccount(isTest: true, snapshotDays: 0, isSyncing: true))
    }
}
