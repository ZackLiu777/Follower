//
//  AppLanguage.swift
//  Follower
//
//  语言枚举与持久化。语言切换仅作用于 UI 层，不渗入数据层。

import Foundation

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable {
    case english    = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese   = "ja"

    var displayName: String {
        switch self {
        case .english:              return "English"
        case .chineseSimplified:    return "简体中文"
        case .chineseTraditional:   return "繁體中文"
        case .japanese:             return "日本語"
        }
    }

    /// 用于 Apple 本地化 API 的 language code
    var localeIdentifier: String {
        rawValue
    }
}

// MARK: - Language Persistence

final class LanguageStore: Sendable {
    static let shared = LanguageStore()

    private let key = "com.follower.AppLanguage"

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
        }
    }
}
