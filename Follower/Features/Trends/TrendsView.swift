//
//  TrendsView.swift
//  Follower
//
//  Sigma: 趋势统计图表页。
//
//  页面结构（从上到下）：
//    NavigationStack
//      └── ZStack
//            ├── 渐变背景层（随主题切换）
//            └── ScrollView
//                  ├── ErrorBanner（条件）
//                  ├── 时间窗 Picker（日/周/月/年）—— 原生 segmented 风格
//                  ├── 6 个 TrendChart 卡片（粉丝/互动/点赞/评论/分享/浏览）
//                  └── GrowthSummary（2 列网格，展示各指标绝对变化量）
//
//  数据流：
//    viewModel.loadInitialAccount() → loadTrends(accountId)
//      → rawMetrics 缓存（日+月 Metric）
//      → chartData(for:) 调用 TimeSeriesEngine.aggregate() 按窗口聚合
//      → TrendChart 渲染
//
//  主题同步：通过 @Environment(\.theme) 读取渐变 + 图表配色，切换即时响应。
//

import SwiftUI

/// 趋势统计图表页 — 多指标柱状图 + 时间窗选择 + 增长摘要网格
struct TrendsView: View {

    // ── 环境依赖 ──
    @EnvironmentObject private var appState: AppState           // 全局状态：主题 / 语言 / 试用
    @ObservedObject var viewModel: TrendsViewModel              // 数据加载 + 窗口切换
    @Environment(\.theme) private var theme                     // 当前主题色板（渐变 / 图表配色）

    // ── Body ──
    var body: some View {
        NavigationStack {
            ZStack {
                /// 渐变背景层 — 独立于滚动内容，不随 ScrollView 移动
                backgroundView
                ScrollView {
                    /// 错误横幅 — 数据加载失败时从顶部滑入
                    if let error = viewModel.errorMessage {
                        ErrorBanner(
                            message: error,
                            onDismiss: { viewModel.errorMessage = nil },
                            onRetry: nil
                        )
                        .padding(.top, 8)
                    }
                    VStack(spacing: 12) {
                        /// 时间窗分段选择器（日/周/月/年）
                        timeWindowPicker
                        /// 六个统计图表卡片 — 每个指标一张
                        /// 指标列表由 TrendsViewModel.visibleMetricTypes 定义
                        ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                            TrendChart(
                                dataPoints: viewModel.chartData(for: metricType),
                                barGradientStart: theme.chartBarGradientStart,
                                barGradientEnd: theme.chartBarGradientEnd,
                                title: metricType.localizedName,
                                timeWindow: viewModel.selectedWindow
                            )
                            .padding(.horizontal, 12)
                        }
                        /// 增长摘要 — 仅当任一指标有数据时展示
                        if hasAnyData {
                            aggregateGrowthSummary
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollContentBackground(.hidden)   // 隐藏系统默认滚动背景，让渐变透出
            }
            .navigationTitle(loc(L10n.Trends.title))
        }
        .task {
            await viewModel.loadInitialAccount()    // 页面出现时加载账号 → 加载趋势数据
        }
    }

    // MARK: - Background
    /// 全屏渐变背景，色彩随主题切换
    private var backgroundView: some View {
        LinearGradient(
            colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Time Window Picker
    /// 日 / 周 / 月 / 年 四段选择器
    /// system segmented 控件 — iOS 26/27 原生自带 Liquid Glass 渲染
    private var timeWindowPicker: some View {
        Picker("Window", selection: Binding(get: { viewModel.selectedWindow }, set: { w in Task { await viewModel.selectWindow(w) } })) {
            ForEach(TimeWindow.allCases, id: \.self) { window in
                Text(window.localizedName).tag(window)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    // MARK: - Growth Summary
    /// 判断是否有任意指标包含可计算的趋势数据（至少 2 个点）
    private var hasAnyData: Bool {
        TrendsViewModel.visibleMetricTypes.contains {
            !viewModel.chartData(for: $0).isEmpty
        }
    }

    /// 2 列网格 — 展示每个指标的绝对变化量（首值 → 末值）
    /// 仅渲染有 ≥2 个数据点的指标，单点或无数据不显示
    private var aggregateGrowthSummary: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                let points = viewModel.chartData(for: metricType)
                if let first = points.first, let last = points.last, points.count > 1 {
                    let change = last.value - first.value
                    summaryItem(
                        label: metricType.localizedName,
                        value: String(format: "%+.0f", change),
                        isPositive: change >= 0
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    /// 单个增长摘要项 — 数值 + 标签
    /// 正增长 = 绿色，负增长 = 红色，卡片使用 regularMaterial 毛玻璃背景
    private func summaryItem(label: String, value: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(isPositive ? theme.positiveGreen : theme.negativeRed)
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}