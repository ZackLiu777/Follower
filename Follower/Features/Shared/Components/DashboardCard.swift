//
//  DashboardCard.swift
//  Follower
//
//  共享卡片样式 — Liquid Glass 玻璃效果（参考 App/Glass.swift 示例）：
//  基础材质 + 表面提亮渐变 + 实线边缘高光 + 悬浮阴影。
//  性能：光晕 blur 羽化层已移除（滚动掉帧主源之一），边缘高光由实线层承担；
//  阴影 radius 10→6（per-pixel 投影采样范围减半）。
//  useLiquidGlass 关闭时（Mono Stone）退化为 cardSurface 平铺。
//

import SwiftUI

// MARK: - Liquid Glass 修饰器

/// 官方 Liquid Glass 质感（性能优化版）：
/// 毛玻璃材质（或静态半透明填充）+ 垂直微弱渐变 + 实线边缘高光。
/// 性能要点：
/// - 光晕 blur 羽化层已移除（滚动每帧重渲的最大成本），高光由实线层承担
/// - 阴影层已移除：深色下黑色投影在深色背景上不可见（纯 GPU 成本），浅色本就是无阴影
/// - `usesMaterial: false`（小卡片/tile）：毛玻璃 → 静态半透明填充。material 是滚动掉帧
///   的主因——每帧重采样背后内容；静态填充零采样。视觉：材质感减弱，描边+渐变保持玻璃感
struct FollowerGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    /// false：静态半透明填充替代 ultraThinMaterial（滚动路径的小卡片建议开启，省每帧重采样）
    var usesMaterial: Bool = true

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            // 1. 基础背景：毛玻璃材质（每帧重采样）或静态半透明填充（零采样）
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        usesMaterial
                            ? AnyShapeStyle(.ultraThinMaterial)
                            : AnyShapeStyle(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.35))
                    )
            )
            // 2. 玻璃微弱渐变
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.09),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            // 3. 边缘白线（实线层，无 blur）— 仅深色主题显示；浅色主题取消
            .overlay {
                if theme.isDark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.25), location: 0.0),
                                    .init(color: Color.white.opacity(0.02), location: 0.18),
                                    .init(color: Color.white.opacity(0.02), location: 0.82),
                                    .init(color: Color.white.opacity(0.25), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                }
            }
    }
}

// MARK: - DashboardCard

/// 圆角卡片 — Liquid Glass 玻璃 / 平铺 cardSurface 两分支
struct DashboardCard: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    func body(content: Content) -> some View {
        if useLiquidGlass {
            content.followerGlassEffect(cornerRadius: 16)
        } else {
            // 非 Liquid Glass (如 Mono Stone): 直接用 cardSurface
            content
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
}

// MARK: - Liquid Glass 纯背景（.background() 场景）

/// Liquid Glass 纯背景形状 — 与 FollowerGlassModifier 同逻辑（无 shadow，边缘白线仅深色显示）
struct LiquidGlassCardBackground: View {
    var cornerRadius: CGFloat = 16

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        // 边缘白线（实线层，无 blur 光晕 — 性能：去每帧 blur 重渲）— 仅深色主题
        .overlay {
            if theme.isDark {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                .init(color: Color.white.opacity(0.02), location: 0.18),
                                .init(color: Color.white.opacity(0.02), location: 0.82),
                                .init(color: Color.white.opacity(0.28), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        // 无 shadow 层：深色黑色投影在深色背景上不可见（纯 GPU 成本），浅色本无阴影
    }
}

extension View {
    /// 应用 Liquid Glass 玻璃效果
    /// - Parameter usesMaterial: false 时用静态半透明填充替代毛玻璃材质（滚动路径小卡片建议开启）
    func followerGlassEffect(cornerRadius: CGFloat = 16, usesMaterial: Bool = true) -> some View {
        modifier(FollowerGlassModifier(cornerRadius: cornerRadius, usesMaterial: usesMaterial))
    }

    /// 应用圆角 Liquid Glass 卡片样式
    func dashboardCard() -> some View { modifier(DashboardCard()) }
}
