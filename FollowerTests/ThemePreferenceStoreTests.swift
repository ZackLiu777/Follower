//
//  ThemePreferenceStoreTests.swift
//  FollowerTests
//
//  主题偏好持久化单元测试 — 隔离 UserDefaults suite，不污染标准域。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for ThemePreferenceStore — fallback on empty/invalid, save/load roundtrip
struct ThemePreferenceStoreTests {
    private let suiteName = "com.follower.tests.themePreference"

    /// 每个测试前清空隔离 suite，保证无残留
    init() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// 无存储值 → loadTheme 返回 fallback（默认主题 .appleDark）
    @Test func testLoadThemeFallsBackWhenEmpty() {
        let store = ThemePreferenceStore(defaults: UserDefaults(suiteName: suiteName)!)
        #expect(store.loadTheme(fallback: .appleDark) == .appleDark)
    }

    /// saveTheme → loadTheme 往返一致（持久化主题退出重进保持）
    @Test func testSaveAndLoadThemeRoundtrip() {
        let store = ThemePreferenceStore(defaults: UserDefaults(suiteName: suiteName)!)
        store.saveTheme(.pureBlack)
        #expect(store.loadTheme(fallback: .appleDark) == .pureBlack)
    }

    /// 非法存储值 → loadTheme 回退 fallback，不崩溃
    @Test func testLoadThemeFallsBackOnInvalidValue() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("not_a_theme", forKey: ThemePreferenceStore.themeKey)
        let store = ThemePreferenceStore(defaults: defaults)
        #expect(store.loadTheme(fallback: .appleDark) == .appleDark)
    }

    /// 无存储值 → loadLightTheme 返回 fallback（浅色主题偏好 .instagram）
    @Test func testLoadLightThemeFallsBackWhenEmpty() {
        let store = ThemePreferenceStore(defaults: UserDefaults(suiteName: suiteName)!)
        #expect(store.loadLightTheme(fallback: .instagram) == .instagram)
    }

    /// saveLightTheme → loadLightTheme 往返一致
    @Test func testSaveAndLoadLightThemeRoundtrip() {
        let store = ThemePreferenceStore(defaults: UserDefaults(suiteName: suiteName)!)
        store.saveLightTheme(.cream)
        #expect(store.loadLightTheme(fallback: .instagram) == .cream)
    }
}
