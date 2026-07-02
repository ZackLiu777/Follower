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

/// 试用管理器协议 — 提供试用状态查询和生命周期管理
protocol TrialManagerProtocol: Sendable {
    /// 试用是否当前活跃
    func isTrialActive() async -> Bool
    /// 剩余试用时间（秒），试用未开始或已结束返回 nil
    func remainingTime() async -> TimeInterval?
    /// 试用总时长（秒）
    var totalTrialDuration: TimeInterval { get }
    /// 首次打开时记录开始时间并启用所有 Premium 功能
    func startTrialIfNeeded() async
    /// 检查试用是否到期，到期则禁用 Premium
    func checkTrialStatus() async
    /// 试用是否已过期
    func isTrialExpired() async -> Bool
}

// MARK: - TrialManager

/// Actor 实现的试用管理器 — 使用 UserDefaults 持久化试用开始/结束状态
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

    /// 初始化：注入 Premium Feature Repository 用于启用/禁用功能
    init(premiumFeatureRepo: PremiumFeatureRepositoryProtocol) {
        self.premiumFeatureRepo = premiumFeatureRepo
    }

    // MARK: - Public

    /// 判断试用是否仍在有效期内
    func isTrialActive() -> Bool {
        guard let start = trialStartDate, !trialManuallyEnded else { return false }
        return Date().timeIntervalSince(start) < totalTrialDuration
    }

    /// 判断试用是否已到期
    func isTrialExpired() -> Bool {
        guard let start = trialStartDate, !trialManuallyEnded else { return false }
        return Date().timeIntervalSince(start) >= totalTrialDuration
    }

    /// 返回剩余试用秒数，试用未开始或已结束返回 nil
    func remainingTime() -> TimeInterval? {
        guard let start = trialStartDate, !trialManuallyEnded else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = totalTrialDuration - elapsed
        return max(0, remaining)
    }

    /// 首次调用时记录试用开始时间并批量启用所有 Premium 功能
    func startTrialIfNeeded() async {
        guard trialStartDate == nil else { return }

        trialStartDate = Date()
        trialManuallyEnded = false

        await enableAllPremiumFeatures(true)
    }

    /// 检查试用状态：若已到期，批量禁用所有 Premium 并标记结束
    func checkTrialStatus() async {
        if isTrialExpired() {
            await enableAllPremiumFeatures(false)
            trialManuallyEnded = true
        }
    }

    // MARK: - Private

    /// 批量启用或禁用全部 Premium 功能
    private func enableAllPremiumFeatures(_ enabled: Bool) async {
        for key in PremiumFeatureKey.allCases {
            let expiresAt = enabled ? Date().addingTimeInterval(totalTrialDuration) : nil
            try? await premiumFeatureRepo.setEnabled(enabled, expiresAt: expiresAt, for: key)
        }
    }

    // MARK: - Keys

    /// UserDefaults 存储键
    private enum Keys {
        static let trialStartDate = "com.follower.trialStartDate"
        static let trialManuallyEnded = "com.follower.trialManuallyEnded"
    }
}
