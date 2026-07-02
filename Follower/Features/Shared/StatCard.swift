//
//  StatCard.swift
//  Follower
//
//  统计指标卡片组件。
//  用于 Dashboard 展示各项基础指标。
//

import SwiftUI

/// 统计指标卡片 — 图标 + 数值 + 标题 + 副标题，毛玻璃圆角卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var subtitle: String?

    /// 垂直布局：图标行（左图标右数值）→ 标题 → 可选副标题
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)

                Spacer()

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// 预览 — 两个 StatCard 并排：Followers（带副标题）和 Engagement
#Preview {
    HStack {
        StatCard(
            title: "Followers",
            value: "1,234",
            icon: "person.2.fill",
            tint: .blue,
            subtitle: "+12 today"
        )
        StatCard(
            title: "Engagement",
            value: "3.2%",
            icon: "heart.fill",
            tint: .pink
        )
    }
    .padding()
}
