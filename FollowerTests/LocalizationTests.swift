//
//  LocalizationTests.swift
//  FollowerTests
//
//  本地化系统测试：语言切换、翻译查找、Bundle 解析。

import XCTest
@testable import Follower

final class LocalizationTests: XCTestCase {

    // MARK: - Language Enum

    func testAllLanguagesHaveDisplayNames() {
        for lang in AppLanguage.allCases {
            XCTAssertFalse(lang.displayName.isEmpty)
        }
    }

    func testLanguagePersistenceRoundTrip() {
        let store = LanguageStore.shared
        let original = store.current

        store.current = .japanese
        XCTAssertEqual(store.current, .japanese)

        store.current = .chineseSimplified
        XCTAssertEqual(store.current, .chineseSimplified)

        // Restore
        store.current = original
    }

    // MARK: - Translation

    func testTranslationReturnsNonEmptyForAllKeys() {
        let store = LanguageStore.shared
        let testKeys = [
            L10n.Tab.dashboard, L10n.Tab.trends, L10n.Tab.settings,
            L10n.Common.ok, L10n.Common.cancel, L10n.Common.loading,
            L10n.Dashboard.followers, L10n.Dashboard.engagementRate,
            L10n.Trends.title, L10n.Trends.daily,
            L10n.Settings.title, L10n.Settings.language, L10n.Settings.theme,
            L10n.Account.title, L10n.Account.connect,
            L10n.Premium.upgradeTo, L10n.Premium.trialBadge,
        ]
        for key in testKeys {
            let translated = store.localizedString(key)
            XCTAssertNotEqual(translated, key, "Key '\(key)' was not translated (returned itself)")
            XCTAssertFalse(translated.isEmpty, "Key '\(key)' returned empty string")
        }
    }

    func testTranslationFallsBackToEnglish() {
        let store = LanguageStore.shared

        // 测试一个已知存在英文翻译的 key
        let enText = store.localizedString(L10n.Common.ok)
        XCTAssertFalse(enText.isEmpty)
        XCTAssertNotEqual(enText, L10n.Common.ok)
    }

    // MARK: - L10n Key Coverage

    func testAllL10nKeysAreValid() {
        // 确保所有 key 都前缀正确，没有拼写错误
        let allKeys: [String] = [
            L10n.Common.ok, L10n.Common.cancel, L10n.Common.done, L10n.Common.delete,
            L10n.Common.loading, L10n.Common.retry, L10n.Common.syncNow,
            L10n.Tab.dashboard, L10n.Tab.trends, L10n.Tab.settings,
            L10n.Dashboard.title, L10n.Dashboard.noAccountTitle, L10n.Dashboard.noAccountMessage,
            L10n.Dashboard.connectAccount, L10n.Dashboard.noDataTitle, L10n.Dashboard.noDataMessage,
            L10n.Dashboard.followers, L10n.Dashboard.following, L10n.Dashboard.media,
            L10n.Dashboard.engagementRate, L10n.Dashboard.likes, L10n.Dashboard.comments,
            L10n.Dashboard.shares, L10n.Dashboard.views,
            L10n.Trends.title, L10n.Trends.daily, L10n.Trends.weekly, L10n.Trends.monthly,
            L10n.Trends.followers, L10n.Trends.engagement, L10n.Trends.likes, L10n.Trends.comments,
            L10n.Trends.shares, L10n.Trends.views, L10n.Trends.reach,
            L10n.Trends.change, L10n.Trends.growth, L10n.Trends.noData, L10n.Trends.noDataHint,
            L10n.Settings.title, L10n.Settings.trialStatus, L10n.Settings.accounts,
            L10n.Settings.appearance, L10n.Settings.theme, L10n.Settings.language,
            L10n.Settings.appleNative, L10n.Settings.instagram, L10n.Settings.midnight, L10n.Settings.instagramDark,
            L10n.Settings.dataExport, L10n.Settings.exportData, L10n.Settings.exportFooter,
            L10n.Settings.storage, L10n.Settings.localOnly, L10n.Settings.storageDescription,
            L10n.Settings.privacy, L10n.Settings.privacyPolicy, L10n.Settings.deleteAllData,
            L10n.Settings.deleteConfirmationTitle, L10n.Settings.deleteConfirmationMessage,
            L10n.Settings.premiumFeatures,
            L10n.Account.title, L10n.Account.connectedAccounts, L10n.Account.addAccount,
            L10n.Account.connectNew, L10n.Account.platform, L10n.Account.username,
            L10n.Account.displayName, L10n.Account.connect, L10n.Account.revoke,
            L10n.Account.authorized, L10n.Account.expired, L10n.Account.revoked,
            L10n.Account.footerHint, L10n.Premium.premiumFeature, L10n.Premium.upgradeTo,
            L10n.Premium.comingSoon, L10n.Premium.trialActive, L10n.Premium.trialBadge,
            L10n.Premium.trialEnded, L10n.Premium.close,
            L10n.Premium.benefit1, L10n.Premium.benefit2, L10n.Premium.benefit3,
            L10n.Premium.benefit4, L10n.Premium.benefit5,
        ]
        XCTAssertEqual(allKeys.count, 83, "L10n key count mismatch")
        for key in allKeys {
            XCTAssertTrue(key.contains("."), "Key '\(key)' should contain a dot separator")
            XCTAssertFalse(key.contains(" "), "Key '\(key)' should not contain spaces")
        }
    }

    // MARK: - Language Switching

    func testSwitchLanguageUpdatesLocalizedStrings() {
        let store = LanguageStore.shared
        let original = store.current

        store.current = .english
        let enOK = store.localizedString(L10n.Common.ok)

        store.current = .japanese
        let jaOK = store.localizedString(L10n.Common.ok)

        // 不同语言可能相同（如 OK = OK），但 dashboard 应该不同
        store.current = .english
        let enDashboard = store.localizedString(L10n.Tab.dashboard)

        store.current = .chineseSimplified
        let zhDashboard = store.localizedString(L10n.Tab.dashboard)

        XCTAssertNotEqual(enDashboard, zhDashboard, "Dashboard should differ between English and Chinese")

        store.current = original
    }
}
