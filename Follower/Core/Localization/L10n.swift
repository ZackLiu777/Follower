//
//  L10n.swift
//  Follower
//
//  统一文本访问入口。直接从 String Catalog 缓存读取，支持 App 内即时语言切换。

import Foundation

// MARK: - Translation Cache

/// 同步翻译缓存：App 启动时加载一次，语言切换时刷新。
@MainActor
final class TranslationCache: @unchecked Sendable {
    static let shared = TranslationCache()

    private var cache: [String: [String: String]] = [:]

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else { return }

        cache.removeAll()
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
            cache[key] = langMap
        }
    }

    /// 重新加载缓存（语言切换后刷新 fallback，但实际翻译通过 lang 参数直接查找）
    func reload() { load() }

    func translate(_ key: String, _ language: AppLanguage) -> String {
        if let localized = cache[key]?[language.rawValue] { return localized }
        if let en = cache[key]?["en"] { return en }
        return key
    }
}

// MARK: - loc()

/// 根据当前 App 内选择的语言返回翻译文本。
/// 切换语言后自动反映新的语言（因为 `LanguageStore.current` 读取 UserDefaults）。
func loc(_ key: String, comment: String = "") -> String {
    let lang = LanguageStore.shared.current
    return TranslationCache.shared.translate(key, lang)
}

// MARK: - L10n Keys

enum L10n {

    // MARK: Common
    enum Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let done = "common.done"
        static let delete = "common.delete"
        static let loading = "common.loading"
        static let error = "common.error"
        static let retry = "common.retry"
        static let syncNow = "common.syncNow"
        static let share = "common.share"
    }

    // MARK: Tab
    enum Tab {
        static let dashboard = "tab.dashboard"
        static let trends = "tab.trends"
        static let settings = "tab.settings"
    }

    // MARK: Dashboard
    enum Dashboard {
        static let title = "dashboard.title"
        static let noAccountTitle = "dashboard.noAccount.title"
        static let noAccountMessage = "dashboard.noAccount.message"
        static let connectAccount = "dashboard.connectAccount"
        static let noDataTitle = "dashboard.noData.title"
        static let noDataMessage = "dashboard.noData.message"
        static let followers = "dashboard.followers"
        static let following = "dashboard.following"
        static let media = "dashboard.media"
        static let engagementRate = "dashboard.engagementRate"
        static let likes = "dashboard.likes"
        static let comments = "dashboard.comments"
        static let shares = "dashboard.shares"
        static let views = "dashboard.views"
    }

    // MARK: Trends
    enum Trends {
        static let title = "trends.title"
        static let daily = "trends.daily"
        static let weekly = "trends.weekly"
        static let monthly = "trends.monthly"
        static let followers = "trends.followers"
        static let engagement = "trends.engagement"
        static let likes = "trends.likes"
        static let comments = "trends.comments"
        static let shares = "trends.shares"
        static let views = "trends.views"
        static let reach = "trends.reach"
        static let change = "trends.change"
        static let growth = "trends.growth"
        static let noData = "trends.noData"
        static let noDataHint = "trends.noDataHint"
    }

    // MARK: Settings
    enum Settings {
        static let title = "settings.title"
        static let trialStatus = "settings.trialStatus"
        static let trialActive = "settings.trialActive"
        static let trialEnded = "settings.trialEnded"
        static let accounts = "settings.accounts"
        static let appearance = "settings.appearance"
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let appleNative = "settings.appleNative"
        static let instagram = "settings.instagram"
        static let midnight = "settings.midnight"
        static let dataExport = "settings.dataExport"
        static let format = "settings.format"
        static let exportData = "settings.exportData"
        static let shareExport = "settings.shareExport"
        static let exportFooter = "settings.exportFooter"
        static let storage = "settings.storage"
        static let localOnly = "settings.localOnly"
        static let storageDescription = "settings.storageDescription"
        static let privacy = "settings.privacy"
        static let privacyPolicy = "settings.privacyPolicy"
        static let deleteAllData = "settings.deleteAllData"
        static let deleteConfirmationTitle = "settings.deleteConfirmation.title"
        static let deleteConfirmationMessage = "settings.deleteConfirmation.message"
        static let premiumFeatures = "settings.premiumFeatures"
    }

    // MARK: Account
    enum Account {
        static let title = "account.title"
        static let connectedAccounts = "account.connectedAccounts"
        static let addAccount = "account.addAccount"
        static let connectNew = "account.connectNew"
        static let platform = "account.platform"
        static let username = "account.username"
        static let displayName = "account.displayName"
        static let connect = "account.connect"
        static let revoke = "account.revoke"
        static let cancel = "account.cancel"
        static let footerHint = "account.footerHint"
        static let authorized = "account.authorized"
        static let expired = "account.expired"
        static let revoked = "account.revoked"
        static let instagram = "account.instagram"
        static let tiktok = "account.tiktok"
        static let requiredFields = "account.requiredFields"
        static let noAccountSelected = "account.noAccountSelected"
    }

    // MARK: Premium
    enum Premium {
        static let premiumFeature = "premium.feature"
        static let upgradeTitle = "premium.upgradeTitle"
        static let upgradeTo = "premium.upgradeTo"
        static let comingSoon = "premium.comingSoon"
        static let trialActive = "premium.trialActive"
        static let trialBadge = "premium.trialBadge"
        static let trialRemaining = "premium.trialRemaining"
        static let trialEnded = "premium.trialEnded"
        static let close = "premium.close"
        static let benefit1 = "premium.benefit1"
        static let benefit2 = "premium.benefit2"
        static let benefit3 = "premium.benefit3"
        static let benefit4 = "premium.benefit4"
        static let benefit5 = "premium.benefit5"
    }
}
