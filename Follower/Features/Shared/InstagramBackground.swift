//
//  InstagramBackground.swift
//  Follower
//
//  深色 UI + Instagram 品牌渐变背景。包裹整个主界面。

import SwiftUI

/// Instagram 品牌渐变色定义
extension LinearGradient {
    static let instagramBrand = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 0.75, blue: 0.10), location: 0.0),
            .init(color: Color(red: 0.96, green: 0.40, blue: 0.25), location: 0.3),
            .init(color: Color(red: 0.82, green: 0.18, blue: 0.49), location: 0.6),
            .init(color: Color(red: 0.55, green: 0.10, blue: 0.70), location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let instagramFaded = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 0.75, blue: 0.10).opacity(0.15), location: 0.0),
            .init(color: Color(red: 0.82, green: 0.18, blue: 0.49).opacity(0.12), location: 0.5),
            .init(color: Color(red: 0.55, green: 0.10, blue: 0.70).opacity(0.10), location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 深色 UI + Instagram 渐变背景容器
struct InstagramDarkContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // 底层：深色基底
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            // 渐变层：Instagram 品牌色淡色叠加
            LinearGradient.instagramFaded
                .ignoresSafeArea()

            // 内容层
            content
        }
    }
}

/// 深色卡片样式 — 半透明深色表面
struct DarkCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func instagramDarkBackground() -> some View {
        modifier(DarkCard())
    }
}
