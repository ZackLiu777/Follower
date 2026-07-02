//
//  HeroMetricCard.swift
//  Follower
//
//  Lambda: Dashboard Hero 粉丝数卡片，大号数字 + delta + mini 趋势。

import SwiftUI
import Charts

/// Hero 指标卡片：大号数字展示 + delta 变化 + Mini 折线趋势图
struct HeroMetricCard: View {
    /// 指标标题，如 "Followers"
    let title: String
    /// 格式化后的主数值，如 "12,345"
    let value: String
    /// 环比变化量
    let delta: Int
    /// 环比变化百分比
    let deltaPercent: Double
    /// 对比周期标签，如 "vs last 7 days"
    let period: String
    /// Mini 折线图数据
    let sparklineData: [Double]

    /// 标题 + 大号数值 + delta + Mini 趋势图 UI
    var body: some View {
        VStack(spacing: 8) {
            // 标题与周期行
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(period)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 大号主数值
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // delta 变化指示（箭头 + 数值 + 百分比）
            HStack(spacing: 4) {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(delta >= 0 ? "+" : "")\(delta)")
                    .fontWeight(.semibold)
                Text("(\(String(format: "%+.1f", deltaPercent))%)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .foregroundColor(delta >= 0 ? .green : .red)

            // Mini 折线图
            if !sparklineData.isEmpty {
                Chart(Array(sparklineData.enumerated()), id: \.0) { i, val in
                    LineMark(x: .value("", i), y: .value("", val))
                        .foregroundStyle(delta >= 0 ? Color.green : Color.red)
                    AreaMark(x: .value("", i), y: .value("", val))
                        .foregroundStyle(
                            LinearGradient(colors: [(delta >= 0 ? Color.green : Color.red).opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                        )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    HeroMetricCard(
        title: "Followers", value: "12,345", delta: 234,
        deltaPercent: 1.9, period: "vs last 7 days",
        sparklineData: [90, 95, 102, 98, 105, 110, 108]
    )
    .padding()
}
