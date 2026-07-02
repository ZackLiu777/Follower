//
//  ThemeTests.swift
//  FollowerTests
//
//  Lambda-2: 6 主题测试 — isDark / gradient / liquidGlass。
//

import XCTest
@testable import Follower

/// Unit tests for Theme system — covers color tokens, dark mode, liquid glass, and AppTheme mapping
final class ThemeTests: XCTestCase {

    static let allThemes: [Theme] = [.appleNative, .instagram, .appleDark, .forest, .roseGold, .monoStone]

    /// 遍历所有 6 个主题 → 每个颜色 token 和 displayName 均非空
    func testAllColorTokensNonNil() {
        for t in Self.allThemes {
            _ = t.backgroundGradientStart; _ = t.backgroundGradientEnd
            _ = t.chartBarGradientStart; _ = t.chartBarGradientEnd
            _ = t.cardSurface; _ = t.accentPrimary
            _ = t.backgroundPrimary; _ = t.textPrimary; _ = t.divider
            XCTAssertFalse(t.displayName.isEmpty)
        }
    }

    /// 检查 isDark 属性 → 仅 appleDark 为 true，其余为 false
    func testIsDarkCorrect() {
        XCTAssertFalse(Theme.appleNative.isDark)
        XCTAssertFalse(Theme.instagram.isDark)
        XCTAssertTrue(Theme.appleDark.isDark)
        XCTAssertFalse(Theme.forest.isDark)
        XCTAssertFalse(Theme.roseGold.isDark)
        XCTAssertFalse(Theme.monoStone.isDark)
    }

    /// 检查 liquidGlassEnabled → 仅 monoStone 为 false，其余为 true
    func testLiquidGlassEnablement() {
        XCTAssertTrue(Theme.appleNative.liquidGlassEnabled)
        XCTAssertTrue(Theme.instagram.liquidGlassEnabled)
        XCTAssertTrue(Theme.appleDark.liquidGlassEnabled)
        XCTAssertTrue(Theme.forest.liquidGlassEnabled)
        XCTAssertTrue(Theme.roseGold.liquidGlassEnabled)
        XCTAssertFalse(Theme.monoStone.liquidGlassEnabled)
    }

    /// AppTheme 枚举计数 → allCases.count == 6
    func testAppThemeCount() { XCTAssertEqual(AppTheme.allCases.count, 6) }

    /// 每个 AppTheme 映射到 Theme → displayName 均非空
    func testAppThemeMapsToTheme() {
        for a in AppTheme.allCases { XCTAssertFalse(a.theme.displayName.isEmpty) }
    }

    /// Theme 值类型复制 → displayName 保持一致
    func testThemeIsSendable() {
        let t = Theme.appleNative; let c = t; XCTAssertEqual(t.displayName, c.displayName)
    }
}
