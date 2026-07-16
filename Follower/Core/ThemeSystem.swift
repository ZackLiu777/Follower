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
    /// 扁平页面背景（取代旧渐变）
    var background: Color { backgroundPrimary }
    /// 内容区域表面色（Posts / Premium 列表背景）
    var surface: Color { backgroundSecondary }
    /// 主题展示名称
    let displayName: String
    /// 是否启用 Liquid Glass 毛玻璃效果
    let liquidGlassEnabled: Bool
    /// 深色模式标志 — 驱动 preferredColorScheme
    let isDark: Bool

    // MARK: - Apple Native（明亮天蓝 → 纯白）

    static let appleNative = Theme(
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        backgroundGradientStart: Color(red: 0.85, green: 0.93, blue: 1.0),
        backgroundGradientEnd: Color(.systemBackground),
        cardSurface: Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.6),
        cardElevated: Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.85),
        textPrimary: .primary, textSecondary: .secondary, textTertiary: Color(.tertiaryLabel), textInverted: .white,
        accentPrimary: Color(red: 0.0, green: 0.45, blue: 0.88), accentSecondary: Color(red: 0.25, green: 0.60, blue: 0.95),
        positiveGreen: .green, negativeRed: .red, warningOrange: .orange,
        chartLine: .blue, chartArea: .blue.opacity(0.15), chartGrid: Color(.systemGray5),
        chartBarGradientStart: Color(red: 0.0, green: 0.45, blue: 0.88),
        chartBarGradientEnd: Color(red: 0.25, green: 0.60, blue: 0.95),
        badgePremiumStart: .orange, badgePremiumEnd: .pink, badgeTrial: .orange, badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: .blue, buttonDestructiveBg: .red, buttonDisabledFg: Color(.systemGray3),
        divider: Color(.separator), navigationBg: Color(.systemBackground), emptyStateIcon: Color(.systemGray3),
        displayName: "Apple Native", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Instagram（亮珊瑚暖橘渐变 → 高级光影白紫）

    /// Instagram 品牌灵感 — 暖珊瑚橘向明亮柔紫过渡，与玫瑰金的粉藕色调拉开差距
    static let instagram = Theme(
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        // 背景渐变：亮珊瑚暖橘 → 柔紫白光（高级光影效果，温暖不腻）
        backgroundGradientStart: Color(red: 1.00, green: 0.89, blue: 0.82),
        backgroundGradientEnd: Color(red: 0.97, green: 0.93, blue: 1.00),
        cardSurface: Color(red: 1.00, green: 0.89, blue: 0.82).opacity(0.48),
        cardElevated: Color(red: 1.00, green: 0.89, blue: 0.82).opacity(0.75),
        textPrimary: Color(red: 0.18, green: 0.06, blue: 0.04),
        textSecondary: Color(red: 0.50, green: 0.22, blue: 0.18),
        textTertiary: Color(red: 0.68, green: 0.42, blue: 0.38), textInverted: .white,
        // Instagram 经典渐变：橙 → 粉
        accentPrimary: Color(red: 0.96, green: 0.33, blue: 0.16),
        accentSecondary: Color(red: 0.87, green: 0.15, blue: 0.48),
        positiveGreen: Color(red: 0.20, green: 0.75, blue: 0.30),
        negativeRed: Color(red: 0.92, green: 0.22, blue: 0.18),
        warningOrange: Color(red: 0.96, green: 0.33, blue: 0.16),
        chartLine: Color(red: 0.87, green: 0.15, blue: 0.48),
        chartArea: Color(red: 0.87, green: 0.15, blue: 0.48).opacity(0.12),
        chartGrid: Color(red: 0.94, green: 0.84, blue: 0.82),
        // 柱状图：Instagram 橙 → 粉渐变
        chartBarGradientStart: Color(red: 0.96, green: 0.33, blue: 0.16),
        chartBarGradientEnd: Color(red: 0.87, green: 0.15, blue: 0.48),
        badgePremiumStart: Color(red: 0.96, green: 0.33, blue: 0.16),
        badgePremiumEnd: Color(red: 0.87, green: 0.15, blue: 0.48),
        badgeTrial: Color(red: 0.96, green: 0.33, blue: 0.16),
        badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: Color(red: 0.87, green: 0.15, blue: 0.48),
        buttonDestructiveBg: .red,
        buttonDisabledFg: Color(.systemGray3),
        divider: Color(red: 0.94, green: 0.84, blue: 0.82),
        navigationBg: Color(.systemBackground),
        emptyStateIcon: Color(red: 0.68, green: 0.42, blue: 0.38),
        displayName: "Instagram", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Apple Dark（深靛蓝 → 暗蓝灰渐变）

    static let appleDark = Theme(
        backgroundPrimary: Color(red: 0.06, green: 0.08, blue: 0.14),
        backgroundSecondary: Color(red: 0.10, green: 0.13, blue: 0.20),
        backgroundGrouped: Color(red: 0.04, green: 0.05, blue: 0.10),
        backgroundGradientStart: Color(red: 0.08, green: 0.12, blue: 0.22),
        backgroundGradientEnd: Color(red: 0.04, green: 0.05, blue: 0.10),
        cardSurface: Color.white.opacity(0.08),
        cardElevated: Color.white.opacity(0.12),
        textPrimary: Color(red: 0.92, green: 0.94, blue: 0.97), textSecondary: Color(red: 0.60, green: 0.65, blue: 0.75),
        textTertiary: Color(red: 0.38, green: 0.42, blue: 0.52), textInverted: .black,
        accentPrimary: Color(red: 0.30, green: 0.60, blue: 1.0), accentSecondary: Color(red: 0.45, green: 0.72, blue: 1.0),
        positiveGreen: Color(red: 0.25, green: 0.80, blue: 0.35), negativeRed: Color(red: 1.0, green: 0.35, blue: 0.35),
        warningOrange: Color(red: 1.0, green: 0.65, blue: 0.20),
        chartLine: Color(red: 0.30, green: 0.60, blue: 1.0),
        chartArea: Color(red: 0.30, green: 0.60, blue: 1.0).opacity(0.12),
        chartGrid: Color.white.opacity(0.08),
        chartBarGradientStart: Color(red: 0.30, green: 0.60, blue: 1.0),
        chartBarGradientEnd: Color(red: 0.20, green: 0.45, blue: 0.85),
        badgePremiumStart: Color(red: 1.0, green: 0.60, blue: 0.20),
        badgePremiumEnd: Color(red: 1.0, green: 0.30, blue: 0.50),
        badgeTrial: Color(red: 1.0, green: 0.60, blue: 0.20), badgeLocked: Color.white.opacity(0.25),
        buttonPrimaryBg: Color(red: 0.30, green: 0.60, blue: 1.0),
        buttonDestructiveBg: Color(red: 0.90, green: 0.25, blue: 0.25),
        buttonDisabledFg: Color.white.opacity(0.20),
        divider: Color.white.opacity(0.08),
        navigationBg: Color(red: 0.06, green: 0.08, blue: 0.14), emptyStateIcon: Color.white.opacity(0.15),
        displayName: "Apple Dark", liquidGlassEnabled: true, isDark: true
    )

    // MARK: - Forest（鲜亮薄荷绿 → 柔白翠绿）

    static let forest = Theme(
        backgroundPrimary: Color(red: 0.74, green: 0.92, blue: 0.82),
        backgroundSecondary: Color(red: 0.68, green: 0.88, blue: 0.78),
        backgroundGrouped: Color(red: 0.80, green: 0.95, blue: 0.88),
        backgroundGradientStart: Color(red: 0.62, green: 0.90, blue: 0.76),
        backgroundGradientEnd: Color(red: 0.88, green: 0.97, blue: 0.92),
        cardSurface: Color(red: 0.62, green: 0.90, blue: 0.76).opacity(0.50),
        cardElevated: Color(red: 0.62, green: 0.90, blue: 0.76).opacity(0.78),
        textPrimary: Color(red: 0.06, green: 0.20, blue: 0.10),
        textSecondary: Color(red: 0.22, green: 0.42, blue: 0.28),
        textTertiary: Color(red: 0.40, green: 0.58, blue: 0.45), textInverted: .white,
        accentPrimary: Color(red: 0.12, green: 0.60, blue: 0.32),
        accentSecondary: Color(red: 0.25, green: 0.75, blue: 0.42),
        positiveGreen: Color(red: 0.15, green: 0.65, blue: 0.35),
        negativeRed: Color(red: 0.88, green: 0.25, blue: 0.20),
        warningOrange: Color(red: 0.88, green: 0.50, blue: 0.12),
        chartLine: Color(red: 0.12, green: 0.60, blue: 0.32),
        chartArea: Color(red: 0.12, green: 0.60, blue: 0.32).opacity(0.12),
        chartGrid: Color.black.opacity(0.05),
        chartBarGradientStart: Color(red: 0.25, green: 0.75, blue: 0.42),
        chartBarGradientEnd: Color(red: 0.12, green: 0.60, blue: 0.32),
        badgePremiumStart: Color(red: 0.25, green: 0.75, blue: 0.42),
        badgePremiumEnd: Color(red: 0.12, green: 0.60, blue: 0.32),
        badgeTrial: Color(red: 0.25, green: 0.75, blue: 0.42), badgeLocked: Color.black.opacity(0.08),
        buttonPrimaryBg: Color(red: 0.12, green: 0.60, blue: 0.32),
        buttonDestructiveBg: Color(red: 0.88, green: 0.25, blue: 0.20),
        buttonDisabledFg: Color.black.opacity(0.06),
        divider: Color.black.opacity(0.06),
        navigationBg: Color(red: 0.74, green: 0.92, blue: 0.82), emptyStateIcon: Color.black.opacity(0.10),
        displayName: "Forest", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Rose Gold（暖玫瑰粉 → 柔白）

    static let roseGold = Theme(
        backgroundPrimary: Color(red: 0.98, green: 0.94, blue: 0.95),
        backgroundSecondary: Color(red: 0.96, green: 0.91, blue: 0.93),
        backgroundGrouped: Color(red: 0.97, green: 0.92, blue: 0.94),
        backgroundGradientStart: Color(red: 0.99, green: 0.90, blue: 0.94),
        backgroundGradientEnd: Color(red: 0.97, green: 0.94, blue: 0.92),
        cardSurface: Color(red: 0.99, green: 0.90, blue: 0.94).opacity(0.50),
        cardElevated: Color(red: 0.99, green: 0.90, blue: 0.94).opacity(0.78),
        textPrimary: Color(red: 0.18, green: 0.10, blue: 0.14),
        textSecondary: Color(red: 0.52, green: 0.38, blue: 0.44),
        textTertiary: Color(red: 0.72, green: 0.55, blue: 0.62), textInverted: .white,
        accentPrimary: Color(red: 0.85, green: 0.42, blue: 0.55),
        accentSecondary: Color(red: 0.95, green: 0.60, blue: 0.72),
        positiveGreen: Color(red: 0.40, green: 0.75, blue: 0.50),
        negativeRed: Color(red: 0.88, green: 0.40, blue: 0.38),
        warningOrange: Color(red: 0.88, green: 0.65, blue: 0.38),
        chartLine: Color(red: 0.85, green: 0.42, blue: 0.55),
        chartArea: Color(red: 0.85, green: 0.42, blue: 0.55).opacity(0.12),
        chartGrid: Color(red: 0.90, green: 0.80, blue: 0.85),
        chartBarGradientStart: Color(red: 0.95, green: 0.60, blue: 0.72),
        chartBarGradientEnd: Color(red: 0.85, green: 0.42, blue: 0.55),
        badgePremiumStart: Color(red: 0.95, green: 0.60, blue: 0.72),
        badgePremiumEnd: Color(red: 0.85, green: 0.42, blue: 0.55),
        badgeTrial: Color(red: 0.85, green: 0.42, blue: 0.55), badgeLocked: Color(red: 0.72, green: 0.55, blue: 0.62),
        buttonPrimaryBg: Color(red: 0.85, green: 0.42, blue: 0.55),
        buttonDestructiveBg: Color(red: 0.88, green: 0.40, blue: 0.38),
        buttonDisabledFg: Color(red: 0.90, green: 0.80, blue: 0.85),
        divider: Color(red: 0.90, green: 0.80, blue: 0.85),
        navigationBg: Color(red: 0.98, green: 0.94, blue: 0.95), emptyStateIcon: Color(red: 0.60, green: 0.45, blue: 0.52),
        displayName: "Rose Gold", liquidGlassEnabled: true, isDark: false
    )

    // MARK: - Mono Stone（暖灰 → 净白，非 Liquid Glass）

    static let monoStone = Theme(
        backgroundPrimary: Color(red: 0.95, green: 0.94, blue: 0.93),
        backgroundSecondary: Color(red: 0.91, green: 0.90, blue: 0.89),
        backgroundGrouped: Color(red: 0.93, green: 0.92, blue: 0.91),
        backgroundGradientStart: Color(red: 0.97, green: 0.96, blue: 0.95),
        backgroundGradientEnd: Color(red: 0.92, green: 0.91, blue: 0.90),
        cardSurface: Color(red: 0.97, green: 0.96, blue: 0.95).opacity(0.70),
        cardElevated: Color(red: 0.97, green: 0.96, blue: 0.95).opacity(0.90),
        textPrimary: Color(red: 0.10, green: 0.10, blue: 0.11),
        textSecondary: Color(red: 0.42, green: 0.42, blue: 0.43),
        textTertiary: Color(red: 0.63, green: 0.63, blue: 0.64),
        textInverted: Color(red: 0.95, green: 0.94, blue: 0.93),
        accentPrimary: Color(red: 0.28, green: 0.28, blue: 0.30),
        accentSecondary: Color(red: 0.42, green: 0.42, blue: 0.43),
        positiveGreen: Color(red: 0.29, green: 0.29, blue: 0.31),
        negativeRed: Color(red: 0.42, green: 0.29, blue: 0.29),
        warningOrange: Color(red: 0.42, green: 0.42, blue: 0.29),
        chartLine: Color(red: 0.28, green: 0.28, blue: 0.30),
        chartArea: Color(red: 0.28, green: 0.28, blue: 0.30).opacity(0.12),
        chartGrid: Color(red: 0.85, green: 0.84, blue: 0.83),
        chartBarGradientStart: Color(red: 0.28, green: 0.28, blue: 0.30),
        chartBarGradientEnd: Color(red: 0.42, green: 0.42, blue: 0.43),
        badgePremiumStart: Color(red: 0.28, green: 0.28, blue: 0.30),
        badgePremiumEnd: Color(red: 0.14, green: 0.14, blue: 0.15),
        badgeTrial: Color(red: 0.28, green: 0.28, blue: 0.30), badgeLocked: Color(red: 0.85, green: 0.84, blue: 0.83),
        buttonPrimaryBg: Color(red: 0.28, green: 0.28, blue: 0.30),
        buttonDestructiveBg: Color(red: 0.42, green: 0.29, blue: 0.29),
        buttonDisabledFg: Color(red: 0.85, green: 0.84, blue: 0.83),
        divider: Color(red: 0.85, green: 0.84, blue: 0.83),
        navigationBg: Color(red: 0.95, green: 0.94, blue: 0.93), emptyStateIcon: Color(red: 0.63, green: 0.63, blue: 0.64),
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
