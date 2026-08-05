//
//  SecondaryMetricRow.swift
//  Follower
//
//  Lambda: Dashboard 次要指标，一行三列。

import SwiftUI

/// 单个次要指标项：数值 + delta 箭头 + 标题
struct SecondaryMetricItem: View {
    /// 指标标题，如 "Engagement Rate"
    let title: String
    /// 格式化后的主数值
    let value: String
    /// 变化量（带符号格式化字符串）
    let delta: String
    /// 变化方向（正数 = 绿色向上）
    let isPositive: Bool
    /// 背景色调
    let tint: Color

    /// 主数值 + delta 趋势 + 标题的垂直卡片布局
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold)
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text(delta)
                    .font(.caption)
            }
            .foregroundColor(isPositive ? .green : .red)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// 三列次要指标行：互动率 / Reach / 帖子数
struct SecondaryMetricRow: View {
    /// 互动率
    let engagementRate: Double
    /// Reach 曝光数
    let reach: Int
    /// 帖子数
    let posts: Int
    /// 互动率环比变化
    let engagementDelta: Double
    /// Reach 环比变化
    let reachDelta: Int
    /// 帖子数环比变化
    let postsDelta: Int

    /// 三列等宽水平布局
    var body: some View {
        HStack(spacing: 10) {
            SecondaryMetricItem(
                title: loc(L10n.Dashboard.engagementRate),
                value: String(format: "%.1f%%", engagementRate * 100),
                delta: String(format: "%+.1f%%", engagementDelta * 100),
                isPositive: engagementDelta >= 0, tint: .pink
            )
            SecondaryMetricItem(
                title: "Reach",
                value: reach >= 1000 ? String(format: "%.1fK", Double(reach) / 1000) : "\(reach)",
                delta: "\(reachDelta >= 0 ? "+" : "")\(reachDelta)",
                isPositive: reachDelta >= 0, tint: .blue
            )
            SecondaryMetricItem(
                title: loc(L10n.Dashboard.media),
                value: "\(posts)",
                delta: "\(postsDelta >= 0 ? "+" : "")\(postsDelta)",
                isPositive: postsDelta >= 0, tint: .orange
            )
        }
    }
}

#Preview {
    SecondaryMetricRow(engagementRate: 0.042, reach: 89000, posts: 52, engagementDelta: 0.003, reachDelta: 1200, postsDelta: 3)
        .padding()
}
