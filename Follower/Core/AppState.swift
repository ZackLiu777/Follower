//
//  AppState.swift
//  Follower
//
//  全局应用状态。

import Foundation
import Combine
import SwiftUI

// MARK: - Sync State

/// App 级同步状态机 — 所有 Tab 共享，确保 UI 状态一致
enum AppSyncState: Sendable {
    case noAccount      // 无账号 → 引导连接
    case readyToSync    // 有账号无数据 → 引导同步
    case syncing        // 同步中 → loading
    case dataReady      // 数据就绪 → 展示内容
}

// 全局应用状态管理器 — 持有主题、语言、试用状态和 Premium 标志位
@MainActor
@Observable
final class AppState {
    let databaseManager: DatabaseManager
    let container: DIContainer

    // MARK: - Published

     var currentTheme: AppTheme = .appleNative
     var currentLanguage: AppLanguage = LanguageStore.shared.current
     var isTrialActive: Bool = false
     var trialStartDate: Date?
    /// Lambda: Premium 解锁状态（同步，所有 PremiumGate 直接读取）
     var premiumEnabledFlags: [String: Bool] = [:]

    // MARK: - Sync State

    /// 全局同步状态 — Dashboard / Trends / Decisions 三个 Tab 共享
    var syncState: AppSyncState = .noAccount

    // MARK: - Account Selection

    /// 全局当前选中账户 ID — Dashboard 切换后，Trends / Decisions 等 Tab 自动响应
    var selectedAccountId: Int64?

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
