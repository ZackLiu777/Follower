//
//  ThemeSystem.swift
//  Follower
//
//  主题系统：Apple Native 与 Instagram 风格。
//  Liquid Glass 仅作为视觉层，不改变业务逻辑。
//  支持性能不足时关闭 Liquid Glass。
//

import SwiftUI

// MARK: - Theme Colors

struct ThemeColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surfaceBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let cardBackground: Color
    let chartLine: Color
    let positiveGreen: Color
    let negativeRed: Color

    // MARK: Apple Native
    static let appleNative = ThemeColors(
        primary: .blue,
        secondary: Color(.systemGray4),
        accent: .blue,
        background: Color(.systemGroupedBackground),
        surfaceBackground: Color(.systemBackground),
        textPrimary: .primary,
        textSecondary: .secondary,
        cardBackground: Color(.secondarySystemGroupedBackground),
        chartLine: .blue,
        positiveGreen: .green,
        negativeRed: .red
    )

    // MARK: Instagram
    static let instagram = ThemeColors(
        primary: Color(red: 0.82, green: 0.18, blue: 0.49),
        secondary: Color(red: 0.96, green: 0.55, blue: 0.31),
        accent: Color(red: 0.82, green: 0.18, blue: 0.49),
        background: Color(.systemGroupedBackground),
        surfaceBackground: Color(.systemBackground),
        textPrimary: .primary,
        textSecondary: .secondary,
        cardBackground: Color(.secondarySystemGroupedBackground),
        chartLine: Color(red: 0.82, green: 0.18, blue: 0.49),
        positiveGreen: Color(red: 0.25, green: 0.72, blue: 0.35),
        negativeRed: Color(red: 0.88, green: 0.23, blue: 0.19)
    )
}

// MARK: - Theme Environment

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = .appleNative
}

private struct UseLiquidGlassKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }

    var useLiquidGlass: Bool {
        get { self[UseLiquidGlassKey.self] }
        set { self[UseLiquidGlassKey.self] = newValue }
    }
}

// MARK: - ViewModifier: ThemeRoot

/// 应用到 App 根层级，注入主题颜色和 Liquid Glass 开关
struct ThemeRootModifier: ViewModifier {
    @ObservedObject var appState: AppState

    private var colors: ThemeColors {
        switch appState.currentTheme {
        case .appleNative: return .appleNative
        case .instagram: return .instagram
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.themeColors, colors)
            .environment(\.useLiquidGlass, true)
    }
}

// MARK: - ViewModifier: LiquidGlass

/// Liquid Glass 视觉效果层。
/// 仅在 useLiquidGlass == true 时应用。
/// 不影响布局和交互结构。
struct LiquidGlassModifier: ViewModifier {
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    func body(content: Content) -> some View {
        if useLiquidGlass {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        } else {
            content
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - View Extension

extension View {
    /// 应用 Liquid Glass 卡片样式（可降级）
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassModifier())
    }

    /// 为整个 App 注入主题
    func withTheme(from appState: AppState) -> some View {
        modifier(ThemeRootModifier(appState: appState))
    }
}
