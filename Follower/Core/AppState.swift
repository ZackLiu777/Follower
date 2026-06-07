//
//  AppState.swift
//  Follower
//
//  全局应用状态。

import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let databaseManager: DatabaseManager
    let container: DIContainer

    // MARK: - Published

    @Published var currentTheme: AppTheme = .appleNative
    @Published var currentLanguage: AppLanguage = LanguageStore.shared.current
    @Published var colorScheme: ColorScheme? = nil
    @Published var isTrialActive: Bool = false
    @Published var trialStartDate: Date?
    /// Lambda: Premium 解锁状态（同步，所有 PremiumGate 直接读取）
    @Published var premiumEnabledFlags: [String: Bool] = [:]

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

    func setLanguage(_ language: AppLanguage) {
        LanguageStore.shared.current = language
        currentLanguage = language
    }
}

extension Notification.Name {
    static let premiumUnlocked = Notification.Name("com.follower.premiumUnlocked")
}
