//
//  InstagramBackground.swift
//  Follower
//
//  深色 UI + Instagram 品牌渐变背景。包裹整个主界面。

import SwiftUI

/// Instagram 品牌渐变色定义 — 黄橙粉紫四段渐变
extension LinearGradient {
    /// 完整品牌色渐变（黄 → 橙 → 粉 → 紫），用于开屏页或强调背景
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
    
    /// 淡色品牌渐变，叠加在深色基底上作为主界面背景
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

/// 深色 UI + Instagram 渐变背景容器 — ZStack 叠加深色底色、淡色渐变、内容
struct InstagramDarkContainer<Content: View>: View {
    let content: Content
    
    /// 使用 @ViewBuilder 闭包注入子视图
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    /// 三层叠加：深色基底 → 渐变层 → 内容层
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

/// 深色卡片样式 — 白色 8% 透明度表面 + 16pt 圆角
struct DarkCard: ViewModifier {
    /// 对 content 应用半透明深色背景和圆角裁剪
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// 提供 .instagramDarkBackground() 修饰符，便捷套用 DarkCard 样式
extension View {
    /// 将视图包装为 Instagram 深色卡片风格
    func instagramDarkBackground() -> some View {
        modifier(DarkCard())
    }
}
