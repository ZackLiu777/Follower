//
//  TrendDetailView.swift
//  Follower
//
//  Sigma: 指标详情页 — 点击 TrendChart 卡片进入，展示全尺寸图表。
//

import SwiftUI

/// 单个指标的统计详情页 — 仅展示全尺寸图表
struct TrendDetailView: View {
    let metricType: MetricType
    let dataPoints: [TrendDataPoint]
    let timeWindow: TimeWindow
    let barGradientStart: Color
    let barGradientEnd: Color

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        ScrollView {
            TrendChart(
                dataPoints: dataPoints,
                barGradientStart: barGradientStart,
                barGradientEnd: barGradientEnd,
                title: metricType.localizedName,
                timeWindow: timeWindow,
                compact: false
            )
            .padding(.horizontal, 12)
            .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(metricType.localizedName)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        let sample = (0..<7).map { i in
            let dayStart = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
            return TrendDataPoint(date: noon, value: Double.random(in: 500...5000))
        }
        TrendDetailView(
            metricType: .followerGrowth,
            dataPoints: sample,
            timeWindow: .week,
            barGradientStart: .blue,
            barGradientEnd: .blue.opacity(0.7)
        )
    }
}
