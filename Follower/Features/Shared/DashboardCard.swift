//
//  DashboardCard.swift
//  Follower
//
//  共享卡片样式 — Liquid Glass 毛玻璃卡片（useLiquidGlass 关闭时用 cardSurface 平铺）。
//  Dashboard / Settings 等页面共用。
//

import SwiftUI

/// 圆角卡片修饰符 — Liquid Glass 毛玻璃 / 平铺 cardSurface 两分支
struct DashboardCard: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    func body(content: Content) -> some View {
        if useLiquidGlass {
            // Liquid Glass 模式: Material 毛玻璃 + theme.cardSurface 半透明色叠层
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                        RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
        } else {
            // 非 Liquid Glass (如 Mono Stone): 直接用 cardSurface
            content
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
}

extension View {
    /// 应用圆角 Liquid Glass 卡片样式
    func dashboardCard() -> some View { modifier(DashboardCard()) }
}
