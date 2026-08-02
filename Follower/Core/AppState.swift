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

// MARK: - Theme Sync State（主题同步状态机）

/// 主题切换同步阶段 — 管理 currentTheme 更新后各注入点（主树 / sheet 内容）的同步
enum ThemeSyncPhase: Equatable, Sendable {
    case idle           // 初始：未发生切换
    case transitioning  // 切换中：currentTheme 已更新，正在向所有注入点同步
    case synced         // 同步完成：所有 UI 已使用新主题
}

// 全局应用状态管理器 — 持有主题、语言、试用状态和 Premium 标志位
@MainActor
@Observable
final class AppState {
    let databaseManager: DatabaseManager
    let container: DIContainer

    // MARK: - Published

    /// 当前主题 — didSet 触发状态机转移：transitioning → 广播 themeChanged → synced
     var currentTheme: AppTheme = .instagram {
        didSet {
            #if DEBUG
            print("[ThemeDebug] currentTheme changed: \(oldValue.rawValue) → \(currentTheme.rawValue)")
            #endif
            guard oldValue != currentTheme else { return }
            // 状态机转移：进入切换中
            themeSyncPhase = .transitioning
            // 广播给所有注入点（sheet 内容等无法靠 environment 传播的视图）
            NotificationCenter.default.post(name: .themeChanged, object: currentTheme)
            // 同步完成
            themeSyncPhase = .synced
        }
    }
    /// 主题同步阶段（状态机当前状态）
    var themeSyncPhase: ThemeSyncPhase = .synced
    /// 用户最后选择的浅色主题 — 「深色模式」开关关闭时恢复
    var lightThemePreference: AppTheme = .instagram
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

    /// 从数据库刷新所有 Premium Feature 的启用状态（缺失 key 自动补建）
    func refreshPremiumFlags() {
        let repo = container.premiumFeatureRepository
        Task {
            // 确保所有 PremiumFeatureKey 在数据库中存在（新增 key 补齐）
            for key in PremiumFeatureKey.allCases {
                let enabled = (try? await repo.isEnabled(key: key)) ?? false
                try? await repo.setEnabled(enabled, for: key) // setEnabled 内部做 upsert
            }
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

    /// 记录浅色主题偏好 — 主题选择器选择浅色主题时调用，「深色模式」开关关闭时恢复
    func rememberLightTheme(_ theme: AppTheme) {
        if !theme.theme.isDark {
            lightThemePreference = theme
        }
    }
}

// 全局通知名称扩展
extension Notification.Name {
    static let premiumUnlocked = Notification.Name("com.follower.premiumUnlocked")
    static let accountCreated = Notification.Name("com.follower.accountCreated")
    static let themeChanged = Notification.Name("com.follower.themeChanged")
}
