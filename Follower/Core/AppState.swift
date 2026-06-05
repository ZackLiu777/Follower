//
//  AppState.swift
//  Follower
//
//  全局应用状态。

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let databaseManager: DatabaseManager
    let container: DIContainer

    // MARK: - Published

    @Published var currentTheme: AppTheme = .appleNative
    @Published var currentLanguage: AppLanguage = LanguageStore.shared.current
    @Published var isTrialActive: Bool = false
    @Published var trialStartDate: Date?

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        self.container = DIContainer(databaseManager: databaseManager)
    }

    func setLanguage(_ language: AppLanguage) {
        LanguageStore.shared.current = language
        currentLanguage = language
    }
}
