//
//  AppState.swift
//  Follower
//
//  全局应用状态。

import Foundation
import Combine
import SwiftUI

// 全局应用状态管理器 — 持有主题、语言、试用状态和 Premium 标志位
@MainActor
final class AppState: ObservableObject {
    let databaseManager: DatabaseManager
    let container: DIContainer

    // MARK: - Published

    @Published var currentTheme: AppTheme = .appleNative
    @Published var currentLanguage: AppLanguage = LanguageStore.shared.current
    @Published var isTrialActive: Bool = false
    @Published var trialStartDate: Date?
    /// Lambda: Premium 解锁状态（同步，所有 PremiumGate 直接读取）
    @Published var premiumEnabledFlags: [String: Bool] = [:]

    /// 从数据库刷新所有 Premium Feature 的启用状态
    func refreshPremiumFlags() {
        let repo = container.premiumFeatureRepository
        Task {
            var flags: [String: Bool] = [:]
            for key in PremiumFeatureKey.allCases {
                flags[key.rawValue] = (try? await repo.isEnabled(key: key)) ?? false
            }
            premiumEnabledFlags = flags
        }
    }

    /// 初始化：创建 DI 容器、监听 Premium 解锁通知、首次加载标志位
    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        self.container = DIContainer(databaseManager: databaseManager)
        // 监听 Premium 解锁通知，刷新标志位
        NotificationCenter.default.addObserver(forName: .premiumUnlocked, object: nil, queue: .main) { [weak self] _ in
            self?.refreshPremiumFlags()
        }
        // 初始加载（TrialManager.startTrial 可能已启用）
        refreshPremiumFlags()
    }

    /// 切换应用语言并持久化
    func setLanguage(_ language: AppLanguage) {
        LanguageStore.shared.current = language
        currentLanguage = language
    }
}

// 全局通知名称扩展
extension Notification.Name {
    static let premiumUnlocked = Notification.Name("com.follower.premiumUnlocked")
}
