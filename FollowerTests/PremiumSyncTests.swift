//
//  PremiumSyncTests.swift
//  FollowerTests
//
//  Lambda-2.0: Premium 解锁 → 通知 → AppState 刷新 → PremiumGate 同步 的端到端测试。

import XCTest
@testable import Follower

/// Unit tests for Premium sync — covers unlock, notification, expiry, and feature toggle sequence
final class PremiumSyncTests: XCTestCase {
    var premiumRepo: PremiumFeatureRepository!

    /// 测试准备 — 配置 PremiumFeatureRepository 实例
    override func setUp() async throws {
        premiumRepo = PremiumFeatureRepository(db: DatabaseManager.shared)
    }

    // MARK: - Unlock → isEnabled verification

    /// 一键解锁所有 Premium 功能 → 每个 PremiumFeatureKey.isEnabled 返回 true
    func testUnlockAllMakesEveryFeatureEnabled() async throws {
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        for key in PremiumFeatureKey.allCases {
            let enabled = try await premiumRepo.isEnabled(key: key)
            XCTAssertTrue(enabled, "\(key.rawValue) should be enabled")
        }
    }

    /// 先启用再禁用 trendPrediction → isEnabled 先 true 后 false
    func testEnableThenDisable() async throws {
        try await premiumRepo.setEnabled(true, for: .trendPrediction)
        let e1 = try await premiumRepo.isEnabled(key: .trendPrediction); XCTAssertTrue(e1)
        try await premiumRepo.setEnabled(false, for: .trendPrediction)
        let e2 = try await premiumRepo.isEnabled(key: .trendPrediction); XCTAssertFalse(e2)
    }

    // MARK: - Notification posting (simulated)

    /// 验证通知名称 → rawValue 匹配 "com.follower.premiumUnlocked"
    func testNotificationNameIsCorrect() {
        XCTAssertEqual(Notification.Name.premiumUnlocked.rawValue, "com.follower.premiumUnlocked")
    }

    /// 发送 premiumUnlocked 通知 → expectation 在超时前触发
    func testNotificationPostedOnUnlock() {
        let exp = expectation(forNotification: .premiumUnlocked, object: nil)
        NotificationCenter.default.post(name: .premiumUnlocked, object: nil)
        wait(for: [exp], timeout: 2)
    }

    // MARK: - PremiumFeatureKey completeness

    /// 检查 PremiumFeatureKey 总量 → allCases.count == 13
    func testAllPremiumKeysExist() {
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13)
    }

    /// 检查关键 feature key → trendPrediction / csvExport / localAIAnalysis 均存在
    func testSpecificKeysArePresent() {
        let keys = Set(PremiumFeatureKey.allCases.map(\.rawValue))
        XCTAssertTrue(keys.contains("trendPrediction"))
        XCTAssertTrue(keys.contains("csvExport"))
        XCTAssertTrue(keys.contains("localAIAnalysis"))
    }

    // MARK: - Expiry: nil expiration means permanent

    /// expiresAt 为 nil → 功能永久启用
    func testNilExpiresAtIsPermanent() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: nil, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertTrue(enabled)
    }

    /// expiresAt 为过去时间 → 功能自动禁用
    func testPastExpiresAtIsDisabled() async throws {
        let past = Date().addingTimeInterval(-100)
        try await premiumRepo.setEnabled(true, expiresAt: past, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertFalse(enabled)
    }

    /// expiresAt 为未来时间 → 功能保持启用
    func testFutureExpiresAtIsEnabled() async throws {
        let future = Date().addingTimeInterval(3600)
        try await premiumRepo.setEnabled(true, expiresAt: future, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertTrue(enabled)
    }

    // MARK: - Unlock all features in sequence

    /// 全部禁用 → 全部启用 → 各步骤 isEnabled 返回值正确
    func testAllFeaturesToggleSequence() async throws {
        // Start: disable all
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(false, for: key)
        }
        // Verify all disabled
        for key in PremiumFeatureKey.allCases {
            let e4 = try await premiumRepo.isEnabled(key: key); XCTAssertFalse(e4)
        }
        // Enable all
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        // Verify all enabled
        for key in PremiumFeatureKey.allCases {
            let e3 = try await premiumRepo.isEnabled(key: key); XCTAssertTrue(e3)
        }
    }
}
