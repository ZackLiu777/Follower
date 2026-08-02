//
//  DashboardCard.swift
//  Follower
//
//  共享卡片样式 — 4 层 Liquid Glass 玻璃效果（参考 App/Glass.swift 示例）：
//  基础材质 + 表面提亮渐变 + 物理边缘高光 + 悬浮阴影。
//  useLiquidGlass 关闭时（Mono Stone）退化为 cardSurface 平铺。
//

import SwiftUI

// MARK: - Liquid Glass 修饰器

/// 官方 Liquid Glass 质感（忠实还原 Glass.swift 透亮光晕版）：
/// 基础毛玻璃 + 垂直微弱渐变 + 光晕层（blur 羽化的边缘溢出光）+ 实线层（锐利切边）+ 悬浮阴影
struct FollowerGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            // 1. 基础毛玻璃材质
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            // 3. 【光晕层】模拟光线照射在玻璃边缘的溢出光线 (Edge Specular Blur)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.35), location: 0.0), // 顶部高光光晕
                                .init(color: .clear, location: 1.0),
                                .init(color: .clear, location: 1.0),
                                .init(color: Color.white.opacity(0.35), location: 1.0) // 底部次级光晕
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .blur(radius: 2) // 核心：通过羽化创造真实光效
            )
            // 4. 【实线层】玻璃切边的物理高光锐利边框
            .overlay(
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
            )
            // 5. 悬浮阴影
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
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

/// Liquid Glass 纯背景形状 — 与 Glass.swift 透亮光晕版一致
struct LiquidGlassCardBackground: View {
    var cornerRadius: CGFloat = 16

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
        // 【光晕层】blur 羽化的边缘溢出光
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.65), location: 0.0),
                            .init(color: .clear, location: 0.25),
                            .init(color: .clear, location: 0.75),
                            .init(color: Color.white.opacity(0.30), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 2)
        )
        // 【实线层】锐利切边
        .overlay(
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
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

extension View {
    /// 应用 4 层 Liquid Glass 玻璃效果
    func followerGlassEffect(cornerRadius: CGFloat = 16) -> some View {
        modifier(FollowerGlassModifier(cornerRadius: cornerRadius))
    }

    /// 应用圆角 Liquid Glass 卡片样式
    func dashboardCard() -> some View { modifier(DashboardCard()) }
}
