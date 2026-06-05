//
//  AppLanguage.swift
//  Follower
//
//  语言枚举、持久化、Bundle 翻译查找。

import Foundation

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
}

// MARK: - LanguageStore

final class LanguageStore: @unchecked Sendable {
    static let shared = LanguageStore()

    private let key = "com.follower.AppLanguage"
    private let appleLanguagesKey = "AppleLanguages"

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

    private var currentBundle: Bundle = .main

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

    func localizedString(_ key: String) -> String {
        let value = currentBundle.localizedString(forKey: key, value: key, table: nil)
        // 如果返回 key 本身，说明没找到翻译，fallback 到 main bundle
        if value == key {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return value
    }
}
