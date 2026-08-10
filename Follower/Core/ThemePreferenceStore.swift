//
//  ThemePreferenceStore.swift
//  Follower
//
//  主题偏好持久化 — UserDefaults 读写当前主题与浅色主题偏好。
//  独立存储类：可注入隔离 suite 做单元测试，不污染标准域。
//

import Foundation

/// 主题偏好持久化 — 当前主题 + 浅色主题偏好（「深色模式」开关恢复用）
struct ThemePreferenceStore {
    /// UserDefaults 存储键
    static let themeKey = "com.follower.themePreference"
    static let lightThemeKey = "com.follower.lightThemePreference"

    private let defaults: UserDefaults

    /// 注入存储域 — 测试传 UserDefaults(suiteName:)，默认标准域
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 读取当前主题（无存储值或非法值 → fallback）
    func loadTheme(fallback: AppTheme) -> AppTheme {
        guard let raw = defaults.string(forKey: Self.themeKey),
              let theme = AppTheme(rawValue: raw) else { return fallback }
        return theme
    }

    /// 保存当前主题
    func saveTheme(_ theme: AppTheme) {
        defaults.set(theme.rawValue, forKey: Self.themeKey)
    }

    /// 读取浅色主题偏好（无存储值或非法值 → fallback）
    func loadLightTheme(fallback: AppTheme) -> AppTheme {
        guard let raw = defaults.string(forKey: Self.lightThemeKey),
              let theme = AppTheme(rawValue: raw) else { return fallback }
        return theme
    }

    /// 保存浅色主题偏好
    func saveLightTheme(_ theme: AppTheme) {
        defaults.set(theme.rawValue, forKey: Self.lightThemeKey)
    }
}
