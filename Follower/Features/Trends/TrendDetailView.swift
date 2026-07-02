//
//  TrendDetailView.swift
//  Follower
//
//  Sigma: 指标详情页 — 点击 TrendChart 卡片进入，展示 Hero 数值 + 全尺寸图表 + 统计摘要。
//

import SwiftUI

/// 单个指标的统计详情页：Hero 当前值 + 周期变化 + 完整图表 + min/max/avg 摘要
struct TrendDetailView: View {
    /// 当前分析的指标类型（followerGrowth / reach / engagement 等）
    let metricType: MetricType
    /// 该指标的时间序列数据点
    let dataPoints: [TrendDataPoint]
    /// 时间窗口（week / month / year）
    let timeWindow: TimeWindow
    /// 图表柱状渐变起始色
    let barGradientStart: Color
    /// 图表柱状渐变结束色
    let barGradientEnd: Color

    /// 主题环境
    @Environment(\.theme) private var theme

    // ── Computed Stats ──

    /// 最新值（最后一个数据点）
    private var latestValue: Double { dataPoints.last?.value ?? 0 }
    /// 起始值（第一个数据点）
    private var firstValue: Double { dataPoints.first?.value ?? 0 }
    /// 变化量 = 最新值 - 起始值
    private var change: Double { latestValue - firstValue }
    /// 变化百分比 = (change / firstValue) * 100
    private var changePercent: Double {
        firstValue > 0 ? (change / firstValue) * 100 : 0
    }
    /// 周期内最小值
    private var minValue: Double { dataPoints.map(\.value).min() ?? 0 }
    /// 周期内最大值
    private var maxValue: Double { dataPoints.map(\.value).max() ?? 0 }
    /// 周期内均值
    private var avgValue: Double {
        guard !dataPoints.isEmpty else { return 0 }
        return dataPoints.map(\.value).reduce(0, +) / Double(dataPoints.count)
    }

    // ── Body ──

    /// 根布局
    var body: some View {
        ZStack {
            // 主题渐变背景
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Hero 卡片 — 当前值 + 变化量 + 变化百分比
                    heroCard

                    // 完整尺寸图表
                    TrendChart(
                        dataPoints: dataPoints,
                        barGradientStart: barGradientStart,
                        barGradientEnd: barGradientEnd,
                        title: metricType.localizedName,
                        timeWindow: timeWindow
                    )
                    .padding(.horizontal, 12)

                    // 统计摘要网格 — min / max / avg
                    statsGrid

                    // 周期变化摘要
                    changeSummary
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(metricType.localizedName)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Card

    /// Hero 卡片 — 当前值 + 变化量 + 变化百分比
    private var heroCard: some View {
        VStack(spacing: 8) {
            Text(formatValue(latestValue))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline)
                Text(String(format: "%+.0f", change))
                    .font(.title3).fontWeight(.semibold)
                Text("(\(String(format: "%+.1f", changePercent))%)")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            .foregroundColor(change >= 0 ? theme.positiveGreen : theme.negativeRed)

            Text(timeWindow.localizedName)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Stats Grid

    /// 统计摘要网格 — min / max / avg / total Δ
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCell(title: loc(L10n.Premium.avgEventsPerDay),  // reuse "Average" semantic
                     value: formatValue(avgValue),
                     icon: "target",
                     color: theme.accentPrimary)
            statCell(title: "Max",
                     value: formatValue(maxValue),
                     icon: "arrow.up",
                     color: theme.positiveGreen)
            statCell(title: "Min",
                     value: formatValue(minValue),
                     icon: "arrow.down",
                     color: theme.negativeRed)
            statCell(title: loc(L10n.Dashboard.media),  // reuse "Total Δ"
                     value: String(format: "%+.0f", change),
                     icon: "arrow.left.arrow.right",
                     color: change >= 0 ? theme.positiveGreen : theme.negativeRed)
        }
        .padding(.horizontal)
    }

    /// 单个统计格子：SF Symbol 图标 + 数值 + 标签
    private func statCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.title3).fontWeight(.bold).foregroundColor(theme.textPrimary)
            Text(title).font(.caption).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Change Summary

    /// 周期变化摘要 — 方向 + 幅度的自然语言描述
    private var changeSummary: some View {
        VStack(spacing: 6) {
            Text("Period Summary").font(.headline).foregroundColor(theme.textPrimary)

            let points = dataPoints.count
            let direction = change >= 0 ? "up" : "down"
            let absChange = String(format: "%.0f", abs(change))

            Text("Over this \(timeWindow.localizedName.lowercased()), your \(metricType.localizedName.lowercased()) went \(direction) by \(absChange) across \(points) data points.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    /// 数值格式化：>=10K 显示 .1fK，>=1K 显示无小数，<1 保留两位
    private func formatValue(_ value: Double) -> String {
        if abs(value) >= 10000 { return String(format: "%.1fK", value / 1000) }
        else if abs(value) >= 1000 { return String(format: "%.0f", value) }
        else if abs(value) >= 1 { return String(format: "%.1f", value) }
        else { return String(format: "%.2f", value) }
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
