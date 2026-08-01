//
//  ThemeTests.swift
//  FollowerTests
//
//  Lambda-2: 6 主题测试 — isDark / gradient / liquidGlass。
//

import Testing
@testable import Follower

/// Unit tests for Theme system — covers color tokens, dark mode, liquid glass, and AppTheme mapping
struct ThemeTests {

    static let allThemes: [Theme] = [.appleNative, .instagram, .appleDark, .forest, .roseGold, .monoStone]

    /// 遍历所有 6 个主题 → 每个颜色 token 和 displayName 均非空
    @Test func testAllColorTokensNonNil() {
        for t in Self.allThemes {
            _ = t.backgroundGradientStart
            _ = t.backgroundGradientEnd
            _ = t.chartBarGradientStart
            _ = t.chartBarGradientEnd
            _ = t.cardSurface
            _ = t.accentPrimary
            _ = t.backgroundPrimary
            _ = t.textPrimary
            _ = t.divider
            #expect(!t.displayName.isEmpty)
        }
    }

    /// 每个主题的背景渐变数组 → 至少 3 色，且首尾色与双色 token 一致（保证与旧背景观感衔接）
    @Test func testBackgroundGradientColors() {
        for t in Self.allThemes {
            #expect(t.backgroundGradientColors.count >= 3,
                    "\(t.displayName) should have at least 3 gradient colors")
            #expect(t.backgroundGradientColors.first == t.backgroundGradientStart,
                    "\(t.displayName) gradient start should match backgroundGradientStart")
            #expect(t.backgroundGradientColors.last == t.backgroundGradientEnd,
                    "\(t.displayName) gradient end should match backgroundGradientEnd")
        }
    }

    /// 检查 isDark 属性 → 仅 appleDark 为 true，其余为 false
    @Test func testIsDarkCorrect() {
        #expect(!Theme.appleNative.isDark)
        #expect(!Theme.instagram.isDark)
        #expect(Theme.appleDark.isDark)
        #expect(!Theme.forest.isDark)
        #expect(!Theme.roseGold.isDark)
        #expect(!Theme.monoStone.isDark)
    }

    /// 检查 liquidGlassEnabled → 仅 monoStone 为 false，其余为 true
    @Test func testLiquidGlassEnablement() {
        #expect(Theme.appleNative.liquidGlassEnabled)
        #expect(Theme.instagram.liquidGlassEnabled)
        #expect(Theme.appleDark.liquidGlassEnabled)
        #expect(Theme.forest.liquidGlassEnabled)
        #expect(Theme.roseGold.liquidGlassEnabled)
        #expect(!Theme.monoStone.liquidGlassEnabled)
    }

    /// AppTheme 枚举计数 → allCases.count == 6
    @Test func testAppThemeCount() {
        #expect(AppTheme.allCases.count == 6)
    }

    /// 每个 AppTheme 映射到 Theme → displayName 均非空
    @Test func testAppThemeMapsToTheme() {
        for a in AppTheme.allCases {
            #expect(!a.theme.displayName.isEmpty)
        }
    }

    /// Theme 值类型复制 → displayName 保持一致
    @Test func testThemeIsSendable() {
        let t = Theme.appleNative
        let c = t
        #expect(t.displayName == c.displayName)
    }
}
