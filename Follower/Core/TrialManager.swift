//
//  TrialManager.swift
//  Follower
//
//  免费试用管理器，负责：
//  - 首次打开记录试用开始时间
//  - 1 小时试用倒计时
//  - 试用期间开放全部 Premium 入口
//  - 试用结束后仅保留基础版功能
//

import Foundation

// MARK: - TrialManagerProtocol

protocol TrialManagerProtocol: Sendable {
    func isTrialActive() async -> Bool
    func remainingTime() async -> TimeInterval?
    var totalTrialDuration: TimeInterval { get }
    func startTrialIfNeeded() async
    func checkTrialStatus() async
    func isTrialExpired() async -> Bool
}

// MARK: - TrialManager

final actor TrialManager: TrialManagerProtocol {
    private let premiumFeatureRepo: PremiumFeatureRepositoryProtocol

    /// 试用总时长：1 小时
    let totalTrialDuration: TimeInterval = 3600

    /// 试用开始时间（UserDefaults 存储）
    private var trialStartDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.trialStartDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.trialStartDate)
        }
    }

    /// 试用是否已被用户手动结束
    private var trialManuallyEnded: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.trialManuallyEnded)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.trialManuallyEnded)
        }
    }

    init(premiumFeatureRepo: PremiumFeatureRepositoryProtocol) {
        self.premiumFeatureRepo = premiumFeatureRepo
    }

    // MARK: - Public

    func isTrialActive() -> Bool {
        guard let start = trialStartDate, !trialManuallyEnded else { return false }
        return Date().timeIntervalSince(start) < totalTrialDuration
    }

    func isTrialExpired() -> Bool {
        guard let start = trialStartDate, !trialManuallyEnded else { return false }
        return Date().timeIntervalSince(start) >= totalTrialDuration
    }

    func remainingTime() -> TimeInterval? {
        guard let start = trialStartDate, !trialManuallyEnded else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = totalTrialDuration - elapsed
        return max(0, remaining)
    }

    func startTrialIfNeeded() async {
        guard trialStartDate == nil else { return }

        trialStartDate = Date()
        trialManuallyEnded = false

        await enableAllPremiumFeatures(true)
    }

    func checkTrialStatus() async {
        if isTrialExpired() {
            await enableAllPremiumFeatures(false)
            trialManuallyEnded = true
        }
    }

    // MARK: - Private

    private func enableAllPremiumFeatures(_ enabled: Bool) async {
        for key in PremiumFeatureKey.allCases {
            let expiresAt = enabled ? Date().addingTimeInterval(totalTrialDuration) : nil
            try? await premiumFeatureRepo.setEnabled(enabled, expiresAt: expiresAt, for: key)
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let trialStartDate = "com.follower.trialStartDate"
        static let trialManuallyEnded = "com.follower.trialManuallyEnded"
    }
}
