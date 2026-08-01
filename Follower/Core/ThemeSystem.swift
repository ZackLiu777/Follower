//
//  ThemeSystem.swift
//  Follower
//
//  Lambda-2: 6 套主题。isDark 驱动 preferredColorScheme，渐变背景 + 毛玻璃卡片。
//

import SwiftUI

// MARK: - Theme

/// 主题色板 — 定义背景、文字、图表、徽章、按钮等全套颜色 token
struct Theme: Sendable {
    /// 背景渐变（多色支持）— 页面背景渐变使用的颜色数组，通常 3 色
    let backgroundGradientColors: [Color]
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundGrouped: Color
    let backgroundGradientStart: Color
    let backgroundGradientEnd: Color
    let cardSurface: Color
    let cardElevated: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverted: Color
    let accentPrimary: Color
    let accentSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    let warningOrange: Color
    let chartLine: Color
    let chartArea: Color
    let chartGrid: Color
    let chartBarGradientStart: Color
    let chartBarGradientEnd: Color
    let badgePremiumStart: Color
    let badgePremiumEnd: Color
    let badgeTrial: Color
    let badgeLocked: Color
    let buttonPrimaryBg: Color
    let buttonDestructiveBg: Color
    let buttonDisabledFg: Color
    let divider: Color
    let navigationBg: Color
    let emptyStateIcon: Color
    /// 内容区域表面色（Posts / Premium 列表背景）
    var surface: Color { backgroundSecondary }
    /// 主题展示名称
    let displayName: String
    /// 是否启用 Liquid Glass 毛玻璃效果
    let liquidGlassEnabled: Bool
    /// 深色模式标志 — 驱动 preferredColorScheme
    let isDark: Bool

    // MARK: - Apple Native（明亮天蓝 → 浅蓝渐变，玻璃卡片）

    static let appleNative = Theme(
        // 背景渐变（三色）：明亮天蓝 → 白 → 浅青
        backgroundGradientColors: [
            .blue.opacity(0.25),
            .white,
            .cyan.opacity(0.15)
        ],
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        backgroundGradientStart: .blue.opacity(0.25),
        backgroundGradientEnd: .cyan.opacity(0.15),
        // 同色系玻璃：用渐变起始色的低不透明度，与背景完美融合
        cardSurface: .blue.opacity(0.10),
        // elevated 稍实，但依然是同色系
        cardElevated: .blue.opacity(0.20),
        textPrimary: .primary, textSecondary: .secondary, textTertiary: Color(.tertiaryLabel), textInverted: .white,
        accentPrimary: .blue, accentSecondary: .cyan,
        positiveGreen: .green, negativeRed: .red, warningOrange: .orange,
        chartLine: .blue, chartArea: .blue.opacity(0.15), chartGrid: Color(.systemGray5),
        chartBarGradientStart: .blue,
        chartBarGradientEnd: .cyan,
        badgePremiumStart: .orange, badgePremiumEnd: .pink, badgeTrial: .orange, badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: .blue, buttonDestructiveBg: .red, buttonDisabledFg: Color(.systemGray3),
        divider: Color(.separator), navigationBg: Color(.systemBackground), emptyStateIcon: Color(.systemGray3),
        displayName: "Apple Native", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Instagram（亮珊瑚暖橘渐变 → 高级光影白紫）

    /// Instagram 品牌灵感 — 暖珊瑚橘向明亮柔紫过渡，与玫瑰金的粉藕色调拉开差距
    static let instagram = Theme(
        // 背景渐变（三色）：Instagram 品牌暖橘 → 粉 → 紫
        backgroundGradientColors: [
            .orange.opacity(0.30),
            .pink.opacity(0.20),
            .purple.opacity(0.18)
        ],
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        // 背景渐变：暖橘 → 柔紫（Instagram 经典黄橙粉紫的光影表达）
        backgroundGradientStart: .orange.opacity(0.30),
        backgroundGradientEnd: .purple.opacity(0.18),
        cardSurface: .orange.opacity(0.12),
        cardElevated: .orange.opacity(0.22),
        textPrimary: .black,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel), textInverted: .white,
        // Instagram 经典渐变：橙 → 粉
        accentPrimary: .orange,
        accentSecondary: .pink,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .pink,
        chartArea: .pink.opacity(0.12),
        chartGrid: .gray.opacity(0.18),
        // 柱状图：Instagram 橙 → 粉渐变
        chartBarGradientStart: .orange,
        chartBarGradientEnd: .pink,
        badgePremiumStart: .orange,
        badgePremiumEnd: .pink,
        badgeTrial: .orange,
        badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: .pink,
        buttonDestructiveBg: .red,
        buttonDisabledFg: Color(.systemGray3),
        divider: .gray.opacity(0.20),
        navigationBg: Color(.systemBackground),
        emptyStateIcon: .gray.opacity(0.5),
        displayName: "Instagram", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Apple Dark（深靛蓝 → 暗蓝灰渐变）

    // MARK: - Apple Dark（深黑 → 暗蓝渐变）

    static let appleDark = Theme(
        // 背景渐变（三色）：深靛蓝 → 暗蓝 → 近黑
        backgroundGradientColors: [
            .indigo.opacity(0.30),
            .blue.opacity(0.15),
            .black
        ],
        backgroundPrimary: .black,
        backgroundSecondary: .gray.opacity(0.12),
        backgroundGrouped: .black,
        backgroundGradientStart: .indigo.opacity(0.30),
        backgroundGradientEnd: .black,
        cardSurface: .gray.opacity(0.15),
        cardElevated: .gray.opacity(0.22),
        textPrimary: .white,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel),
        textInverted: .black,
        accentPrimary: .blue,
        accentSecondary: .cyan,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .blue,
        chartArea: .blue.opacity(0.15),
        chartGrid: .gray.opacity(0.25),
        chartBarGradientStart: .blue,
        chartBarGradientEnd: .indigo,
        badgePremiumStart: .orange,
        badgePremiumEnd: .pink,
        badgeTrial: .orange,
        badgeLocked: .gray.opacity(0.35),
        buttonPrimaryBg: .blue,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.25),
        navigationBg: .black,
        emptyStateIcon: .gray.opacity(0.5),
        displayName: "Apple Dark", liquidGlassEnabled: true, isDark: true
    )
    // MARK: - Forest（鲜亮薄荷绿 → 柔白翠绿）

    static let forest = Theme(
        // 背景渐变（三色）：鲜亮薄荷 → 翠绿 → 柔白
        backgroundGradientColors: [
            .mint.opacity(0.40),
            .green.opacity(0.20),
            .white
        ],
        backgroundPrimary: .mint.opacity(0.15),
        backgroundSecondary: .mint.opacity(0.10),
        backgroundGrouped: .mint.opacity(0.08),
        backgroundGradientStart: .mint.opacity(0.40),
        backgroundGradientEnd: .white,
        cardSurface: .white.opacity(0.40),
        cardElevated: .white.opacity(0.65),
        textPrimary: .black,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel), textInverted: .white,
        accentPrimary: .green,
        accentSecondary: .mint,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .green,
        chartArea: .green.opacity(0.12),
        chartGrid: .gray.opacity(0.15),
        chartBarGradientStart: .mint,
        chartBarGradientEnd: .green,
        badgePremiumStart: .mint,
        badgePremiumEnd: .green,
        badgeTrial: .mint, badgeLocked: .gray.opacity(0.30),
        buttonPrimaryBg: .green,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.30),
        divider: .gray.opacity(0.15),
        navigationBg: .mint.opacity(0.15), emptyStateIcon: .gray.opacity(0.40),
        displayName: "Forest", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Rose Gold（暖玫瑰粉 → 柔白）

    static let roseGold = Theme(
        // 背景渐变（三色）：暖玫瑰粉 → 藕粉 → 柔白
        backgroundGradientColors: [
            .pink.opacity(0.28),
            .pink.opacity(0.14),
            .white
        ],
        backgroundPrimary: .white,
        backgroundSecondary: .pink.opacity(0.06),
        backgroundGrouped: .pink.opacity(0.04),
        backgroundGradientStart: .pink.opacity(0.28),
        backgroundGradientEnd: .white,
        cardSurface: .white.opacity(0.50),
        cardElevated: .white.opacity(0.75),
        textPrimary: .black,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel), textInverted: .white,
        accentPrimary: .pink,
        accentSecondary: .purple,
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .pink,
        chartArea: .pink.opacity(0.12),
        chartGrid: .gray.opacity(0.15),
        chartBarGradientStart: .pink,
        chartBarGradientEnd: .purple,
        badgePremiumStart: .pink,
        badgePremiumEnd: .purple,
        badgeTrial: .pink, badgeLocked: .gray.opacity(0.35),
        buttonPrimaryBg: .pink,
        buttonDestructiveBg: .red,
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.15),
        navigationBg: .pink.opacity(0.06), emptyStateIcon: .gray.opacity(0.45),
        displayName: "Rose Gold", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Mono Stone（暖灰 → 净白，非 Liquid Glass）

    static let monoStone = Theme(
        // 背景渐变（三色）：净白 → 浅灰 → 中灰
        backgroundGradientColors: [
            .gray.opacity(0.05),
            .gray.opacity(0.15),
            .gray.opacity(0.28)
        ],
        backgroundPrimary: .gray.opacity(0.08),
        backgroundSecondary: .gray.opacity(0.12),
        backgroundGrouped: .gray.opacity(0.10),
        backgroundGradientStart: .gray.opacity(0.05),
        backgroundGradientEnd: .gray.opacity(0.28),
        cardSurface: .white.opacity(0.70),
        cardElevated: .white.opacity(0.90),
        textPrimary: .black,
        textSecondary: .gray,
        textTertiary: Color(.tertiaryLabel),
        textInverted: .white,
        accentPrimary: .black.opacity(0.75),
        accentSecondary: .gray.opacity(0.60),
        positiveGreen: .gray.opacity(0.70),
        negativeRed: .gray.opacity(0.70),
        warningOrange: .gray.opacity(0.70),
        chartLine: .black.opacity(0.65),
        chartArea: .gray.opacity(0.15),
        chartGrid: .gray.opacity(0.25),
        chartBarGradientStart: .black.opacity(0.60),
        chartBarGradientEnd: .gray.opacity(0.45),
        badgePremiumStart: .black.opacity(0.60),
        badgePremiumEnd: .black.opacity(0.80),
        badgeTrial: .black.opacity(0.60), badgeLocked: .gray.opacity(0.35),
        buttonPrimaryBg: .black.opacity(0.75),
        buttonDestructiveBg: .gray.opacity(0.70),
        buttonDisabledFg: .gray.opacity(0.35),
        divider: .gray.opacity(0.30),
        navigationBg: .gray.opacity(0.08), emptyStateIcon: .gray.opacity(0.50),
        displayName: "Mono Stone", liquidGlassEnabled: false, isDark: false
    )
}

// MARK: - AppTheme

/// 主题枚举 — 6 套可选主题，提供 theme / displayName 计算属性
enum AppTheme: String, CaseIterable {
    case appleNative, instagram, appleDark, forest, roseGold, monoStone

    /// 将枚举值映射到对应的 Theme 实例
    var theme: Theme {
        switch self {
        case .appleNative: .appleNative
        case .instagram:   .instagram
        case .appleDark:   .appleDark
        case .forest:      .forest
        case .roseGold:    .roseGold
        case .monoStone:   .monoStone
        }
    }

    /// 本地化后的主题展示名称
    var displayName: String {
        switch self {
        case .appleNative: loc(L10n.Settings.appleNative)
        case .instagram:   loc(L10n.Settings.instagram)
        case .appleDark:   loc(L10n.Settings.appleDark)
        case .forest:      loc(L10n.Settings.forest)
        case .roseGold:    loc(L10n.Settings.roseGold)
        case .monoStone:   loc(L10n.Settings.monoStone)
        }
    }
}

// MARK: - Environment

/// 自定义 Environment key：注入当前 Theme
private struct ThemeKey: EnvironmentKey { static let defaultValue: Theme = .appleNative }
/// 自定义 Environment key：控制 Liquid Glass 效果
private struct LiquidGlassKey: EnvironmentKey { static let defaultValue: Bool = true }

extension EnvironmentValues {
    /// 从环境读取当前主题
    var theme: Theme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
    /// 从环境读取 Liquid Glass 开关状态
    var useLiquidGlass: Bool { get { self[LiquidGlassKey.self] } set { self[LiquidGlassKey.self] = newValue } }
}

// MARK: - Modifiers

/// ViewModifier：将 Theme 注入 SwiftUI 环境
struct ThemeModifier: ViewModifier {
    let theme: Theme
    func body(content: Content) -> some View {
        content.environment(\.theme, theme).environment(\.useLiquidGlass, theme.liquidGlassEnabled)
    }
}

/// ViewModifier：毛玻璃卡片样式（Material + 半透明色板 + 分割线 + 阴影）
struct LiquidGlassCard: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(theme.divider, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
    }
}

extension View {
    /// 为视图子树注入指定主题
    func withTheme(_ theme: Theme) -> some View { modifier(ThemeModifier(theme: theme)) }
    /// 应用 Liquid Glass 毛玻璃卡片样式
    func liquidGlassCard() -> some View { modifier(LiquidGlassCard()) }
}
