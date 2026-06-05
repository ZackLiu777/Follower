//
//  AppLanguage.swift
//  Follower
//
//  语言枚举、持久化、以及翻译查找。
//  绕过 NSLocalizedString，直接从 String Catalog 读取，实现 App 内即时语言切换。

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

    var localeIdentifier: String { rawValue }
}

// MARK: - LanguageStore (actor for thread safety)

final actor LanguageStore {
    static let shared = LanguageStore()

    private let key = "com.follower.AppLanguage"
    private var translationCache: [String: [String: String]] = [:]
    private var isLoaded = false

    nonisolated var current: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let lang = AppLanguage(rawValue: raw) else {
                return .english
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
        }
    }

    /// 确保翻译缓存已加载
    private func ensureLoaded() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            isLoaded = true
            return
        }

        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let locals = entry["localizations"] as? [String: Any] else { continue }
            var langMap: [String: String] = [:]
            for (langCode, langValue) in locals {
                if let lv = langValue as? [String: Any],
                   let unit = lv["stringUnit"] as? [String: Any],
                   let str = unit["value"] as? String {
                    langMap[langCode] = str
                }
            }
            translationCache[key] = langMap
        }
        isLoaded = true
    }

    /// 获取指定 key 的翻译。fallback: key 本身 → 英语 → 德语等 → key
    func translation(for key: String) -> String {
        ensureLoaded()
        let lang = current.rawValue

        if let localized = translationCache[key]?[lang] {
            return localized
        }
        // fallback to English
        if let en = translationCache[key]?["en"] {
            return en
        }
        return key
    }
}
