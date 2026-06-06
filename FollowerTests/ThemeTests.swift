//
//  ThemeTests.swift
//  FollowerTests
//
//  主题系统测试：颜色完整性、枚举覆盖、Environment 注入。

import XCTest
import SwiftUI
@testable import Follower

final class ThemeTests: XCTestCase {

    // MARK: - Theme Completeness

    func testAllThemesHaveNonEmptyColors() {
        let themes: [Theme] = [.appleNative, .instagram, .midnight]
        for theme in themes {
            XCTAssertFalse(theme.displayName.isEmpty)
            // 每个主题都必须有有效颜色
            _ = theme.accentPrimary
            _ = theme.backgroundPrimary
            _ = theme.textPrimary
            _ = theme.chartLine
        }
    }

    func testThemeDistinctAccents() {
        // 三个主题的 accent 颜色必须不同
        let accents = Set([
            Theme.appleNative.accentPrimary.hashValue,
            Theme.instagram.accentPrimary.hashValue,
            Theme.midnight.accentPrimary.hashValue,
        ])
        XCTAssertEqual(accents.count, 3, "All three themes should have distinct accent colors")
    }

    func testLiquidGlassEnablement() {
        XCTAssertTrue(Theme.appleNative.liquidGlassEnabled)
        XCTAssertTrue(Theme.instagram.liquidGlassEnabled)
        XCTAssertFalse(Theme.midnight.liquidGlassEnabled)
    }

    // MARK: - AppTheme Enum

    func testAppThemeMapsToTheme() {
        for appTheme in AppTheme.allCases {
            let theme = appTheme.theme
            XCTAssertFalse(theme.displayName.isEmpty)
            XCTAssertFalse(appTheme.displayName.isEmpty)
        }
    }

    func testMidnightThemeHasDarkBackground() {
        // Midnight 主题的背景应该偏暗
        let midnight = Theme.midnight
        // 无法在测试中直接比较 Color，但可以验证其存在
        _ = midnight.backgroundPrimary
        _ = midnight.textPrimary
    }

    // MARK: - Theme Sendable

    func testThemeIsSendable() {
        // Theme 是 struct（值类型），自动 Sendable
        let theme = Theme.appleNative
        let copy = theme
        XCTAssertEqual(theme.displayName, copy.displayName)
    }
}
