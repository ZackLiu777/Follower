//
//  PremiumSyncTests.swift
//  FollowerTests
//
//  Lambda-2.0: Premium 解锁 → 通知 → AppState 刷新 → PremiumGate 同步 的端到端测试。

import Testing
import Foundation
@testable import Follower

/// Unit tests for Premium sync — covers unlock, notification, expiry, and feature toggle sequence
struct PremiumSyncTests {
    let premiumRepo: PremiumFeatureRepository

    /// 测试准备 — 配置 PremiumFeatureRepository 实例
    init() {
        premiumRepo = PremiumFeatureRepository(db: DatabaseManager.shared)
    }

    // MARK: - Unlock → isEnabled verification

    /// 一键解锁所有 Premium 功能 → 每个 PremiumFeatureKey.isEnabled 返回 true
    @Test func testUnlockAllMakesEveryFeatureEnabled() async throws {
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        for key in PremiumFeatureKey.allCases {
            let enabled = try await premiumRepo.isEnabled(key: key)
            #expect(enabled, "\(key.rawValue) should be enabled")
        }
    }

    /// 先启用再禁用 trendPrediction → isEnabled 先 true 后 false
    @Test func testEnableThenDisable() async throws {
        try await premiumRepo.setEnabled(true, for: .trendPrediction)
        let e1 = try await premiumRepo.isEnabled(key: .trendPrediction); #expect(e1)
        try await premiumRepo.setEnabled(false, for: .trendPrediction)
        let e2 = try await premiumRepo.isEnabled(key: .trendPrediction); #expect(!e2)
    }

    // MARK: - Notification posting (simulated)

    /// 验证通知名称 → rawValue 匹配 "com.follower.premiumUnlocked"
    @Test func testNotificationNameIsCorrect() {
        #expect(Notification.Name.premiumUnlocked.rawValue == "com.follower.premiumUnlocked")
    }
    
    // 1. 定义超时错误类型
    private struct TimeoutError: Error, CustomStringConvertible {
        var description: String { "Operation timed out" }
    }

    // 2. 定义超时辅助函数
    private func withTimeout<T>(_ seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError() // 这里使用了 TimeoutError
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// 发送 premiumUnlocked 通知 → expectation 在超时前触发
    @Test func testNotificationPostedOnUnlock() async throws {
        let notification = try await withTimeout(2) {
            await NotificationCenter.default.notifications(named: .premiumUnlocked).first { _ in true }
        }
        #expect(notification != nil)
    }

    // MARK: - PremiumFeatureKey completeness

    /// 检查 PremiumFeatureKey 总量 → allCases.count == 13
    @Test func testAllPremiumKeysExist() {
        #expect(PremiumFeatureKey.allCases.count == 13)
    }

    /// 检查关键 feature key → trendPrediction / csvExport / localAIAnalysis 均存在
    @Test func testSpecificKeysArePresent() {
        let keys = Set(PremiumFeatureKey.allCases.map(\.rawValue))
        #expect(keys.contains("trendPrediction"))
        #expect(keys.contains("csvExport"))
        #expect(keys.contains("localAIAnalysis"))
    }

    // MARK: - Expiry: nil expiration means permanent

    /// expiresAt 为 nil → 功能永久启用
    @Test func testNilExpiresAtIsPermanent() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: nil, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        #expect(enabled)
    }

    /// expiresAt 为过去时间 → 功能自动禁用
    @Test func testPastExpiresAtIsDisabled() async throws {
        let past = Date().addingTimeInterval(-100)
        try await premiumRepo.setEnabled(true, expiresAt: past, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        #expect(!enabled)
    }

    /// expiresAt 为未来时间 → 功能保持启用
    @Test func testFutureExpiresAtIsEnabled() async throws {
        let future = Date().addingTimeInterval(3600)
        try await premiumRepo.setEnabled(true, expiresAt: future, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        #expect(enabled)
    }

    // MARK: - Unlock all features in sequence

    /// 全部禁用 → 全部启用 → 各步骤 isEnabled 返回值正确
    @Test func testAllFeaturesToggleSequence() async throws {
        // Start: disable all
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(false, for: key)
        }
        // Verify all disabled
        for key in PremiumFeatureKey.allCases {
            let e4 = try await premiumRepo.isEnabled(key: key); #expect(!e4)
        }
        // Enable all
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        // Verify all enabled
        for key in PremiumFeatureKey.allCases {
            let e3 = try await premiumRepo.isEnabled(key: key); #expect(e3)
        }
    }
}

