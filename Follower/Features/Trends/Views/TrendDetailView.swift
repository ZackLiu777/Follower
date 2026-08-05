//
//  TrendDetailView.swift
//  Follower
//
//  Sigma: 指标详情页 — 标题下时间维度切换（日/周/月/年）+ 总计 + 周期标签 + 年份下拉。
//

import SwiftUI

/// 单个指标的统计详情页
struct TrendDetailView: View {
    @Bindable var viewModel: TrendsViewModel
    let metricType: MetricType
    let barGradientStart: Color
    let barGradientEnd: Color

    @Environment(\.theme) private var theme
    /// 详情页时间窗口 — 初始化为总览页当前窗口（进入详情保持同一维度）
    @State private var window: TimeWindow

    init(viewModel: TrendsViewModel, metricType: MetricType, barGradientStart: Color, barGradientEnd: Color) {
        self.viewModel = viewModel
        self.metricType = metricType
        self.barGradientStart = barGradientStart
        self.barGradientEnd = barGradientEnd
        _window = State(initialValue: viewModel.selectedWindow)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // ── 时间维度切换 ──
                    Picker("Window", selection: $window) {
                        ForEach(TimeWindow.allCases, id: \.self) { w in
                            Text(w.localizedName).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    // ── 总计 + 周期标签（切换器下方，左对齐）──
                    VStack(alignment: .leading, spacing: 6) {
                        // 总计（求和，无 +/- 前缀；大小与趋势总览一致，颜色同步主题）
                        Text(formatInt(viewModel.totalValue(for: metricType, in: window)))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(theme.accentPrimary)

                        // 周期标签：今天 / 本周 / 2026年7月（year 模式只显示年份下拉，无固定年份）
                        HStack(spacing: 8) {
                            if window != .year {
                                Text(viewModel.periodLabel(for: window))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textSecondary)
                            }

                            // year 模式：年份下拉（账号创建年 → 当前年，唯一年份入口）
                            if window == .year {
                                Menu {
                                    ForEach(viewModel.availableYears, id: \.self) { year in
                                        Button("\(year)") { viewModel.selectedYear = year }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(viewModel.selectedYear)")
                                            .font(.system(size: 15, weight: .semibold))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(theme.accentPrimary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    // ── 全尺寸图表（隐藏内置标题，由外部渲染）──
                    TrendChart(
                        dataPoints: viewModel.chartData(for: metricType, in: window),
                        barGradientStart: barGradientStart,
                        barGradientEnd: barGradientEnd,
                        title: metricType.localizedName,
                        timeWindow: window,
                        compact: false,
                        showTitle: false
                    )
                    .padding(.horizontal, 12)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(metricType.localizedName)
        .navigationBarTitleDisplayMode(.large)
    }

    private func formatInt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

#Preview {
    NavigationStack {
        let appState = AppState(databaseManager: DatabaseManager.shared)
        let viewModel = TrendsViewModel(
            snapshotRepo: appState.container.snapshotRepository,
            metricRepo: appState.container.metricRepository,
            accountRepo: appState.container.accountRepository
        )
        TrendDetailView(
            viewModel: viewModel,
            metricType: .followerGrowth,
            barGradientStart: .blue,
            barGradientEnd: .blue.opacity(0.7)
        )
    }
}
