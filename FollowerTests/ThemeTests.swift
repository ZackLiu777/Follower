//
//  ThemeTests.swift
//  FollowerTests
//
//  Lambda-2: 6 主题测试 — isDark / gradient / liquidGlass。
//

import XCTest
@testable import Follower

final class ThemeTests: XCTestCase {

    static let allThemes: [Theme] = [.appleNative, .instagram, .appleDark, .forest, .roseGold, .monoStone]

    func testAllColorTokensNonNil() {
        for t in Self.allThemes {
            _ = t.backgroundGradientStart; _ = t.backgroundGradientEnd
            _ = t.chartBarGradientStart; _ = t.chartBarGradientEnd
            _ = t.cardSurface; _ = t.accentPrimary
            _ = t.backgroundPrimary; _ = t.textPrimary; _ = t.divider
            XCTAssertFalse(t.displayName.isEmpty)
        }
    }

    func testIsDarkCorrect() {
        XCTAssertFalse(Theme.appleNative.isDark)
        XCTAssertFalse(Theme.instagram.isDark)
        XCTAssertTrue(Theme.appleDark.isDark)
        XCTAssertFalse(Theme.forest.isDark)
        XCTAssertFalse(Theme.roseGold.isDark)
        XCTAssertFalse(Theme.monoStone.isDark)
    }

    func testLiquidGlassEnablement() {
        XCTAssertTrue(Theme.appleNative.liquidGlassEnabled)
        XCTAssertTrue(Theme.instagram.liquidGlassEnabled)
        XCTAssertTrue(Theme.appleDark.liquidGlassEnabled)
        XCTAssertTrue(Theme.forest.liquidGlassEnabled)
        XCTAssertTrue(Theme.roseGold.liquidGlassEnabled)
        XCTAssertFalse(Theme.monoStone.liquidGlassEnabled)
    }

    func testAppThemeCount() { XCTAssertEqual(AppTheme.allCases.count, 6) }
    func testAppThemeMapsToTheme() {
        for a in AppTheme.allCases { XCTAssertFalse(a.theme.displayName.isEmpty) }
    }

    func testThemeIsSendable() {
        let t = Theme.appleNative; let c = t; XCTAssertEqual(t.displayName, c.displayName)
    }
}
