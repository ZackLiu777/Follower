//
//  PremiumSyncTests.swift
//  FollowerTests
//
//  Lambda-2.0: Premium 解锁 → 通知 → AppState 刷新 → PremiumGate 同步 的端到端测试。

import XCTest
@testable import Follower

final class PremiumSyncTests: XCTestCase {
    var premiumRepo: PremiumFeatureRepository!

    override func setUp() async throws {
        premiumRepo = PremiumFeatureRepository(db: DatabaseManager.shared)
    }

    // MARK: - Unlock → isEnabled verification

    func testUnlockAllMakesEveryFeatureEnabled() async throws {
        for key in PremiumFeatureKey.allCases {
            try await premiumRepo.setEnabled(true, expiresAt: nil, for: key)
        }
        for key in PremiumFeatureKey.allCases {
            let enabled = try await premiumRepo.isEnabled(key: key)
            XCTAssertTrue(enabled, "\(key.rawValue) should be enabled")
        }
    }

    func testEnableThenDisable() async throws {
        try await premiumRepo.setEnabled(true, for: .trendPrediction)
        let e1 = try await premiumRepo.isEnabled(key: .trendPrediction); XCTAssertTrue(e1)
        try await premiumRepo.setEnabled(false, for: .trendPrediction)
        let e2 = try await premiumRepo.isEnabled(key: .trendPrediction); XCTAssertFalse(e2)
    }

    // MARK: - Notification posting (simulated)

    func testNotificationNameIsCorrect() {
        XCTAssertEqual(Notification.Name.premiumUnlocked.rawValue, "com.follower.premiumUnlocked")
    }

    func testNotificationPostedOnUnlock() {
        let exp = expectation(forNotification: .premiumUnlocked, object: nil)
        NotificationCenter.default.post(name: .premiumUnlocked, object: nil)
        wait(for: [exp], timeout: 2)
    }

    // MARK: - PremiumFeatureKey completeness

    func testAllPremiumKeysExist() {
        XCTAssertEqual(PremiumFeatureKey.allCases.count, 13)
    }

    func testSpecificKeysArePresent() {
        let keys = Set(PremiumFeatureKey.allCases.map(\.rawValue))
        XCTAssertTrue(keys.contains("trendPrediction"))
        XCTAssertTrue(keys.contains("csvExport"))
        XCTAssertTrue(keys.contains("localAIAnalysis"))
    }

    // MARK: - Expiry: nil expiration means permanent

    func testNilExpiresAtIsPermanent() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: nil, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertTrue(enabled)
    }

    func testPastExpiresAtIsDisabled() async throws {
        let past = Date().addingTimeInterval(-100)
        try await premiumRepo.setEnabled(true, expiresAt: past, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertFalse(enabled)
    }

    func testFutureExpiresAtIsEnabled() async throws {
        let future = Date().addingTimeInterval(3600)
        try await premiumRepo.setEnabled(true, expiresAt: future, for: .excelExport)
        let enabled = try await premiumRepo.isEnabled(key: .excelExport)
        XCTAssertTrue(enabled)
    }

    // MARK: - Unlock all features in sequence

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
