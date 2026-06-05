//
//  ThemeSystem.swift
//  Follower
//
//  Beta: 完整主题语义系统。Theme 是 Sendable 值类型，安全跨越 actor 边界。
//  支持 Apple Native / Instagram / Midnight Dark 三种风格。

import SwiftUI

// MARK: - Theme

struct Theme: Sendable {
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundGrouped: Color
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
    let displayName: String
    let liquidGlassEnabled: Bool

    // MARK: - Apple Native

    static let appleNative = Theme(
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        cardSurface: Color(.secondarySystemGroupedBackground),
        cardElevated: Color(.tertiarySystemGroupedBackground),
        textPrimary: .primary,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel),
        textInverted: .white,
        accentPrimary: .blue,
        accentSecondary: .blue.opacity(0.7),
        positiveGreen: .green,
        negativeRed: .red,
        warningOrange: .orange,
        chartLine: .blue,
        chartArea: .blue.opacity(0.15),
        chartGrid: Color(.systemGray5),
        badgePremiumStart: .orange,
        badgePremiumEnd: .pink,
        badgeTrial: .orange,
        badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: .blue,
        buttonDestructiveBg: .red,
        buttonDisabledFg: Color(.systemGray3),
        divider: Color(.separator),
        navigationBg: Color(.systemBackground),
        emptyStateIcon: Color(.systemGray3),
        displayName: "Apple Native",
        liquidGlassEnabled: true
    )

    // MARK: - Instagram

    static let instagram = Theme(
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundGrouped: Color(.systemGroupedBackground),
        cardSurface: Color(.secondarySystemGroupedBackground),
        cardElevated: Color(.tertiarySystemGroupedBackground),
        textPrimary: .primary,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel),
        textInverted: .white,
        accentPrimary: Color(red: 0.82, green: 0.18, blue: 0.49),
        accentSecondary: Color(red: 0.96, green: 0.55, blue: 0.31),
        positiveGreen: Color(red: 0.25, green: 0.72, blue: 0.35),
        negativeRed: Color(red: 0.88, green: 0.23, blue: 0.19),
        warningOrange: Color(red: 0.96, green: 0.55, blue: 0.31),
        chartLine: Color(red: 0.82, green: 0.18, blue: 0.49),
        chartArea: Color(red: 0.82, green: 0.18, blue: 0.49).opacity(0.15),
        chartGrid: Color(.systemGray5),
        badgePremiumStart: Color(red: 0.96, green: 0.55, blue: 0.31),
        badgePremiumEnd: Color(red: 0.82, green: 0.18, blue: 0.49),
        badgeTrial: Color(red: 0.96, green: 0.55, blue: 0.31),
        badgeLocked: Color(.systemGray3),
        buttonPrimaryBg: Color(red: 0.82, green: 0.18, blue: 0.49),
        buttonDestructiveBg: .red,
        buttonDisabledFg: Color(.systemGray3),
        divider: Color(.separator),
        navigationBg: Color(.systemBackground),
        emptyStateIcon: Color(.systemGray3),
        displayName: "Instagram",
        liquidGlassEnabled: true
    )

    // MARK: - Midnight Dark

    static let midnight = Theme(
        backgroundPrimary: Color(red: 0.05, green: 0.05, blue: 0.09),
        backgroundSecondary: Color(red: 0.08, green: 0.08, blue: 0.14),
        backgroundGrouped: Color(red: 0.02, green: 0.02, blue: 0.05),
        cardSurface: Color(red: 0.10, green: 0.10, blue: 0.16),
        cardElevated: Color(red: 0.14, green: 0.14, blue: 0.20),
        textPrimary: Color.white.opacity(0.92),
        textSecondary: Color.white.opacity(0.60),
        textTertiary: Color.white.opacity(0.38),
        textInverted: .black,
        accentPrimary: Color(red: 0.40, green: 0.60, blue: 1.0),
        accentSecondary: Color(red: 0.30, green: 0.50, blue: 0.90),
        positiveGreen: Color(red: 0.25, green: 0.78, blue: 0.35),
        negativeRed: Color(red: 1.0, green: 0.35, blue: 0.35),
        warningOrange: Color(red: 1.0, green: 0.65, blue: 0.20),
        chartLine: Color(red: 0.40, green: 0.60, blue: 1.0),
        chartArea: Color(red: 0.40, green: 0.60, blue: 1.0).opacity(0.12),
        chartGrid: Color.white.opacity(0.08),
        badgePremiumStart: Color(red: 1.0, green: 0.60, blue: 0.20),
        badgePremiumEnd: Color(red: 1.0, green: 0.30, blue: 0.50),
        badgeTrial: Color(red: 1.0, green: 0.60, blue: 0.20),
        badgeLocked: Color.white.opacity(0.25),
        buttonPrimaryBg: Color(red: 0.40, green: 0.60, blue: 1.0),
        buttonDestructiveBg: Color(red: 0.90, green: 0.25, blue: 0.25),
        buttonDisabledFg: Color.white.opacity(0.20),
        divider: Color.white.opacity(0.08),
        navigationBg: Color(red: 0.05, green: 0.05, blue: 0.09),
        emptyStateIcon: Color.white.opacity(0.15),
        displayName: "Midnight",
        liquidGlassEnabled: false
    )
}

// MARK: - AppTheme Enum

enum AppTheme: String, CaseIterable {
    case appleNative
    case instagram
    case midnight

    var theme: Theme {
        switch self {
        case .appleNative: return .appleNative
        case .instagram: return .instagram
        case .midnight: return .midnight
        }
    }

    var displayName: String {
        switch self {
        case .appleNative: return loc(L10n.Settings.appleNative)
        case .instagram: return loc(L10n.Settings.instagram)
        case .midnight: return loc(L10n.Settings.midnight)
        }
    }
}

// MARK: - Environment Keys

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .appleNative
}

private struct LiquidGlassKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var useLiquidGlass: Bool {
        get { self[LiquidGlassKey.self] }
        set { self[LiquidGlassKey.self] = newValue }
    }
}

// MARK: - View Modifiers

struct ThemeModifier: ViewModifier {
    let theme: Theme
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
    func withTheme(_ theme: Theme) -> some View {
        modifier(ThemeModifier(theme: theme))
    }
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCard())
    }
}
