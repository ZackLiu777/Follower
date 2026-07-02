//
//  AppLanguage.swift
//  Follower
//
//  语言枚举、持久化、Bundle 翻译查找。

import Foundation

/// 支持的应用语言枚举
enum AppLanguage: String, CaseIterable {
    case english    = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese   = "ja"
    
    /// 语言的本地化展示名称
    var displayName: String {
        switch self {
        case .english:              return "English"
        case .chineseSimplified:    return "简体中文"
        case .chineseTraditional:   return "繁體中文"
        case .japanese:             return "日本語"
        }
    }
}

// MARK: - LanguageStore

/// 语言持久化管理器 — 切换语言时同步更新 UserDefaults 和 Bundle
final class LanguageStore: @unchecked Sendable {
    /// 共享单例
    static let shared = LanguageStore()
    
    /// UserDefaults 存储键
    private let key = "com.follower.AppLanguage"
    /// 系统语言列表键（AppleLanguages）
    private let appleLanguagesKey = "AppleLanguages"
    
    /// 当前语言，写入时自动持久化并重新加载 Bundle
    var current: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let lang = AppLanguage(rawValue: raw) else {
                return .english
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            UserDefaults.standard.set([newValue.rawValue], forKey: appleLanguagesKey)
            UserDefaults.standard.synchronize()
            // 重新加载当前语言的 bundle
            reloadBundle()
        }
    }
    
    // MARK: - Bundle Lookup
    
    /// 当前语言对应的 Bundle，用于翻译查找
    private var currentBundle: Bundle = .main
    
    /// 根据 current 语言重新加载对应的 .lproj Bundle
    private func reloadBundle() {
        let lang = current.rawValue
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            currentBundle = bundle
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            currentBundle = bundle
        } else {
            currentBundle = .main
        }
    }
    
    /// 从当前语言 Bundle 查找 key 的翻译，未找到时 fallback 到 main bundle
    func localizedString(_ key: String) -> String {
        let value = currentBundle.localizedString(forKey: key, value: key, table: nil)
        // 如果返回 key 本身，说明没找到翻译，fallback 到 main bundle
        if value == key {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return value
    }
}
