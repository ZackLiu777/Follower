//
//  PremiumUnlockTests.swift
//  FollowerTests
//
//  Premium 解锁功能测试。

import XCTest
@testable import Follower

final class PremiumUnlockTests: XCTestCase {
    var premiumRepo: PremiumFeatureRepository!

    override func setUp() async throws {
        premiumRepo = PremiumFeatureRepository(db: DatabaseManager.shared)
    }

    func testUnlockAllEnablesEveryFeature() async throws {
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
            XCTAssertTrue(enabled, "\(key.rawValue) should be enabled after unlock all")
        }
    }

    func testUnlockAllDoesNotExpire() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: nil, for: .trendPrediction)
        let enabled = try await premiumRepo.isEnabled(key: .trendPrediction)
        XCTAssertTrue(enabled, "Feature with nil expiresAt should be permanently enabled")
    }

    func testPremiumFeatureCount() {
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13, "All 13 premium keys should exist")
    }
}
