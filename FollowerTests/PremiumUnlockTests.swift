//
//  PremiumUnlockTests.swift
//  FollowerTests
//
//  Premium 解锁功能测试。

import Testing
@testable import Follower

/// Unit tests for Premium unlock — covers batch unlock, expiry behavior, and feature count
struct PremiumUnlockTests {
    let premiumRepo: PremiumFeatureRepository

    /// 测试准备 — 配置 PremiumFeatureRepository 实例
    init() {
        premiumRepo = PremiumFeatureRepository(db: DatabaseManager.shared)
    }

    /// 先全部关闭再一键全开 → 每个 key 的 isEnabled 返回 true
    @Test func testUnlockAllEnablesEveryFeature() async throws {
        // 先全部关闭
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(false, for: key)
        }
        // 一键全开
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        // 验证全部开启
        for key in PremiumFeatureKey.allCases {
            let enabled = try await premiumRepo.isEnabled(key: key)
            #expect(enabled, "\(key.rawValue) should be enabled after unlock all")
        }
    }

    /// expiresAt 设为 nil → 功能永久启用，不会过期
    @Test func testUnlockAllDoesNotExpire() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: nil, for: .trendPrediction)
        let enabled = try await premiumRepo.isEnabled(key: .trendPrediction)
        #expect(enabled, "Feature with nil expiresAt should be permanently enabled")
    }

    /// 检查 Premium feature 总数 → allCases.count == 13
    @Test func testPremiumFeatureCount() {
        #expect(PremiumFeatureKey.allCases.count == 13, "All 13 premium keys should exist")
    }
}
