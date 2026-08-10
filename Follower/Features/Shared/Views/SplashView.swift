//
//  SplashView.swift
//  Follower
//
//  开屏页面。主题渐变背景（与所选主题同步，每套主题开屏不同）+
//  App 图标 + 品牌名称。启动后自动过渡到主界面。

import SwiftUI

/// 开屏页 — 主题渐变背景 + 图标 + 品牌名，2 秒动画后回调进入主界面
/// theme: 当前所选主题 — 背景渐变与图标/文字配色全部取自主题 token
struct SplashView: View {
    let theme: Theme
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    var onComplete: () -> Void

    /// 全屏渐变 + 居中图标/文字，入场缩放淡入 → 2 秒后淡出回调
    var body: some View {
        ZStack {
            // 不透明背景底层 — 主题渐变色多为半透明（透明度 0.05 ~ 0.40），
            // 直接铺渐变会透出系统背景（浅色主题呈“透明”）；垫主题主色保证不透，
            // 并与主界面（系统背景 + 渐变）的观感同步
            theme.backgroundPrimary
                .ignoresSafeArea()

            // 主题渐变 — 与主界面背景渐变一致（每套主题开屏不同）
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // App 图标 — 主题强调色
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(theme.accentPrimary.opacity(0.15))
                        .frame(width: 88, height: 88)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.accentPrimary)
                }

                // 品牌名称
                Text("Follower")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)

                Text("Track Your Growth")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // 入场动画 — 缩放 + 淡入
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
            // 2 秒后触发退出 — 先缩小再回调，父级 .transition(.opacity) 接管淡出
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.25)) {
                    scale = 0.95
                    opacity = 0.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onComplete()
                }
            }
        }
    }
}

/// 预览 — 深色主题示例，空回调，展示完整入场动画
#Preview {
    SplashView(theme: .appleDark, onComplete: {})
}
