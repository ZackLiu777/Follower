//
//  SplashView.swift
//  Follower
//
//  开屏页面。Instagram 风格渐变背景 + App 图标 + 品牌名称。
//  启动后自动过渡到主界面。

import SwiftUI

/// 开屏页 — Instagram 渐变背景 + 图标 + 品牌名，2 秒动画后回调进入主界面
struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    var onComplete: () -> Void

    /// 全屏渐变 + 居中图标/文字，入场缩放淡入 → 2 秒后淡出回调
    var body: some View {
        ZStack {
            // Instagram 渐变背景
            instagramGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // App 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.white.opacity(0.2))
                        .frame(width: 88, height: 88)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                // 品牌名称
                Text("Follower")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Track Your Growth")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    onComplete()
                }
            }
        }
    }

    /// Instagram 品牌渐变：黄 → 橙 → 粉 → 紫
    var instagramGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.75, blue: 0.10), location: 0.0),
                .init(color: Color(red: 0.96, green: 0.40, blue: 0.25), location: 0.3),
                .init(color: Color(red: 0.82, green: 0.18, blue: 0.49), location: 0.6),
                .init(color: Color(red: 0.55, green: 0.10, blue: 0.70), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 预览 — 空回调，展示完整入场动画
#Preview {
    SplashView(onComplete: {})
}
