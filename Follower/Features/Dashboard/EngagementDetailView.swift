//
//  EngagementDetailView.swift
//  Follower
//
//  Lambda: 互动详情页 — 互动率趋势 + 维度分解。

import SwiftUI
import Charts

/// 互动详情页：展示互动率 Hero 数字、维度分解条、每日互动柱状图
struct EngagementDetailView: View {
    @Environment(\.theme) private var theme

    /// 总互动率
    let engagementRate: Double
    /// 点赞数
    let likes: Int
    /// 评论数
    let comments: Int
    /// 分享数
    let shares: Int
    /// 总曝光数（用于计算比率）
    let views: Int

    /// 互动率 Hero + 维度分解 + 每日柱状图 UI
    var body: some View {
        ZStack {
            // Theme background gradient
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Rate hero 卡片
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f%%", engagementRate * 100))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("Engagement Rate").font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Breakdown 分解条
                    VStack(spacing: 12) {
                        Text("Breakdown").font(.headline)
                        engagementBar(label: "Likes", value: likes, total: views, color: theme.accentPrimary)
                        engagementBar(label: "Comments", value: comments, total: views, color: theme.positiveGreen)
                        engagementBar(label: "Shares", value: shares, total: views, color: theme.chartLine)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Mock 每日互动柱状图
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Engagement").font(.headline).padding(.horizontal)
                        Chart {
                            ForEach(Array(MockEngagementGenerator.daily().enumerated()), id: \.0) { i, val in
                                BarMark(x: .value("", i), y: .value("", val))
                                    .foregroundStyle(theme.accentPrimary.opacity(0.6))
                            }
                        }
                        .frame(height: 160)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Engagement")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 单项互动维度分解条：标签 + 百分比 + 颜色进度条
    private func engagementBar(label: String, value: Int, total: Int, color: Color) -> some View {
        let rate = total > 0 ? Double(value) / Double(total) : 0
        return VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%%", rate * 100)).font(.subheadline).fontWeight(.medium)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * rate)
            }
            .frame(height: 8)
        }
    }
}

/// 生成每日 Mock 互动率数据的辅助枚举
private enum MockEngagementGenerator {
    /// 返回 7 天随机互动率数组
    static func daily() -> [Double] {
        (0..<7).map { _ in Double.random(in: 0.01...0.08) }
    }
}

#Preview {
    NavigationStack {
        EngagementDetailView(engagementRate: 0.042, likes: 5000, comments: 300, shares: 100, views: 89000)
    }
}
