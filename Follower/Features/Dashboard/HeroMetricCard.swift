//
//  HeroMetricCard.swift
//  Follower
//
//  Lambda: Dashboard Hero 粉丝数卡片，大号数字 + delta + mini 趋势。

import SwiftUI
import Charts

struct HeroMetricCard: View {
    let title: String
    let value: String
    let delta: Int
    let deltaPercent: Double
    let period: String
    let sparklineData: [Double]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(period)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(delta >= 0 ? "+" : "")\(delta)")
                    .fontWeight(.semibold)
                Text("(\(String(format: "%+.1f", deltaPercent))%)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .foregroundColor(delta >= 0 ? .green : .red)

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
