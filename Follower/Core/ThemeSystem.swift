//
//  ThemeSystem.swift
//  Follower
//
//  Beta: 完整主题语义系统。每个 UI 元素从主题上下文获取颜色。
//  支持 Apple Native / Instagram / Midnight Dark 三种风格。

import SwiftUI

// MARK: - Theme Protocol

/// 主题语义 token 集。View 不直接写颜色常量，全部通过此协议获取。
protocol Theme {
    // Background
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var backgroundGrouped: Color { get }

    // Card
    var cardSurface: Color { get }
    var cardElevated: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textInverted: Color { get }

    // Accent
    var accentPrimary: Color { get }
    var accentSecondary: Color { get }

    // Semantic colors
    var positiveGreen: Color { get }
    var negativeRed: Color { get }
    var warningOrange: Color { get }

    // Chart
    var chartLine: Color { get }
    var chartArea: Color { get }
    var chartGrid: Color { get }

    // Badge
    var badgePremiumStart: Color { get }
    var badgePremiumEnd: Color { get }
    var badgeTrial: Color { get }
    var badgeLocked: Color { get }

    // Button
    var buttonPrimaryBg: Color { get }
    var buttonDestructiveBg: Color { get }
    var buttonDisabledFg: Color { get }

    // Misc
    var divider: Color { get }
    var navigationBg: Color { get }
    var emptyStateIcon: Color { get }

    // Theme identity
    var displayName: String { get }
    var liquidGlassEnabled: Bool { get }
}

// MARK: - Apple Native Theme

struct AppleNativeTheme: Theme {
    let displayName = "Apple Native"
    let liquidGlassEnabled = true

    let backgroundPrimary = Color(.systemBackground)
    let backgroundSecondary = Color(.secondarySystemBackground)
    let backgroundGrouped = Color(.systemGroupedBackground)

    let cardSurface = Color(.secondarySystemGroupedBackground)
    let cardElevated = Color(.tertiarySystemGroupedBackground)

    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)
    let textInverted = Color.white

    let accentPrimary = Color.blue
    let accentSecondary = Color.blue.opacity(0.7)

    let positiveGreen = Color.green
    let negativeRed = Color.red
    let warningOrange = Color.orange

    let chartLine = Color.blue
    let chartArea = Color.blue.opacity(0.15)
    let chartGrid = Color(.systemGray5)

    let badgePremiumStart = Color.orange
    let badgePremiumEnd = Color.pink
    let badgeTrial = Color.orange
    let badgeLocked = Color(.systemGray3)

    let buttonPrimaryBg = Color.blue
    let buttonDestructiveBg = Color.red
    let buttonDisabledFg = Color(.systemGray3)

    let divider = Color(.separator)
    let navigationBg = Color(.systemBackground)
    let emptyStateIcon = Color(.systemGray3)
}

// MARK: - Instagram Theme

struct InstagramTheme: Theme {
    let displayName = "Instagram"
    let liquidGlassEnabled = true

    let accentPrimary = Color(red: 0.82, green: 0.18, blue: 0.49)
    let accentSecondary = Color(red: 0.96, green: 0.55, blue: 0.31)

    let backgroundPrimary = Color(.systemBackground)
    let backgroundSecondary = Color(.secondarySystemBackground)
    let backgroundGrouped = Color(.systemGroupedBackground)

    let cardSurface = Color(.secondarySystemGroupedBackground)
    let cardElevated = Color(.tertiarySystemGroupedBackground)

    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)
    let textInverted = Color.white

    let positiveGreen = Color(red: 0.25, green: 0.72, blue: 0.35)
    let negativeRed = Color(red: 0.88, green: 0.23, blue: 0.19)
    let warningOrange = Color(red: 0.96, green: 0.55, blue: 0.31)

    let chartLine = Color(red: 0.82, green: 0.18, blue: 0.49)
    let chartArea = Color(red: 0.82, green: 0.18, blue: 0.49).opacity(0.15)
    let chartGrid = Color(.systemGray5)

    let badgePremiumStart = Color(red: 0.96, green: 0.55, blue: 0.31)
    let badgePremiumEnd = Color(red: 0.82, green: 0.18, blue: 0.49)
    let badgeTrial = Color(red: 0.96, green: 0.55, blue: 0.31)
    let badgeLocked = Color(.systemGray3)

    let buttonPrimaryBg = Color(red: 0.82, green: 0.18, blue: 0.49)
    let buttonDestructiveBg = Color.red
    let buttonDisabledFg = Color(.systemGray3)

    let divider = Color(.separator)
    let navigationBg = Color(.systemBackground)
    let emptyStateIcon = Color(.systemGray3)
}

// MARK: - Midnight Dark Theme

struct MidnightDarkTheme: Theme {
    let displayName = "Midnight"
    let liquidGlassEnabled = false

    let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.09)
    let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.14)
    let backgroundGrouped = Color(red: 0.02, green: 0.02, blue: 0.05)

    let cardSurface = Color(red: 0.10, green: 0.10, blue: 0.16)
    let cardElevated = Color(red: 0.14, green: 0.14, blue: 0.20)

    let textPrimary = Color.white.opacity(0.92)
    let textSecondary = Color.white.opacity(0.60)
    let textTertiary = Color.white.opacity(0.38)
    let textInverted = Color.black

    let accentPrimary = Color(red: 0.40, green: 0.60, blue: 1.0)
    let accentSecondary = Color(red: 0.30, green: 0.50, blue: 0.90)

    let positiveGreen = Color(red: 0.25, green: 0.78, blue: 0.35)
    let negativeRed = Color(red: 1.0, green: 0.35, blue: 0.35)
    let warningOrange = Color(red: 1.0, green: 0.65, blue: 0.20)

    let chartLine = Color(red: 0.40, green: 0.60, blue: 1.0)
    let chartArea = Color(red: 0.40, green: 0.60, blue: 1.0).opacity(0.12)
    let chartGrid = Color.white.opacity(0.08)

    let badgePremiumStart = Color(red: 1.0, green: 0.60, blue: 0.20)
    let badgePremiumEnd = Color(red: 1.0, green: 0.30, blue: 0.50)
    let badgeTrial = Color(red: 1.0, green: 0.60, blue: 0.20)
    let badgeLocked = Color.white.opacity(0.25)

    let buttonPrimaryBg = Color(red: 0.40, green: 0.60, blue: 1.0)
    let buttonDestructiveBg = Color(red: 0.90, green: 0.25, blue: 0.25)
    let buttonDisabledFg = Color.white.opacity(0.20)

    let divider = Color.white.opacity(0.08)
    let navigationBg = Color(red: 0.05, green: 0.05, blue: 0.09)
    let emptyStateIcon = Color.white.opacity(0.15)
}

// MARK: - AppTheme Enum

enum AppTheme: String, CaseIterable {
    case appleNative
    case instagram
    case midnight

    var theme: any Theme {
        switch self {
        case .appleNative: return AppleNativeTheme()
        case .instagram: return InstagramTheme()
        case .midnight: return MidnightDarkTheme()
        }
    }

    var displayName: String {
        switch self {
        case .appleNative: return loc(L10n.Settings.appleNative)
        case .instagram: return loc(L10n.Settings.instagram)
        case .midnight: return "Midnight"
        }
    }
}

// MARK: - Environment Keys

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = AppleNativeTheme()
}

private struct LiquidGlassKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var useLiquidGlass: Bool {
        get { self[LiquidGlassKey.self] }
        set { self[LiquidGlassKey.self] = newValue }
    }
}

// MARK: - Theme Modifiers

struct ThemeModifier: ViewModifier {
    let theme: any Theme

    func body(content: Content) -> some View {
        content
            .environment(\.theme, theme)
            .environment(\.useLiquidGlass, theme.liquidGlassEnabled)
    }
}

struct LiquidGlassCard: ViewModifier {
    @Environment(\.useLiquidGlass) private var useLiquidGlass
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if useLiquidGlass {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        } else {
            content
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension View {
    func withTheme(_ theme: any Theme) -> some View {
        modifier(ThemeModifier(theme: theme))
    }
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCard())
    }
}

// MARK: - Legacy backward-compat (deprecated, use Theme protocol)
struct ThemeColors {
    static let appleNative = AppleNativeTheme()
    static let instagram = InstagramTheme()
}
