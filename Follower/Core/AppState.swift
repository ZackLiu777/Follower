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
    /// Lambda: Premium 解锁后自增，触发 PremiumGate 重新检查
    @Published var premiumRefreshID: Int = 0

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        self.container = DIContainer(databaseManager: databaseManager)
        // 监听 Premium 解锁通知，刷新 PremiumGate
        NotificationCenter.default.addObserver(forName: .premiumUnlocked, object: nil, queue: .main) { [weak self] _ in
            self?.premiumRefreshID += 1
        }
    }

    func setLanguage(_ language: AppLanguage) {
        LanguageStore.shared.current = language
        currentLanguage = language
    }
}

extension Notification.Name {
    static let premiumUnlocked = Notification.Name("com.follower.premiumUnlocked")
}
