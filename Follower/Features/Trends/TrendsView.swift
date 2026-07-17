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
    @Environment(AppState.self) private var appState           // 全局状态：主题 / 语言 / 试用
    @Bindable var viewModel: TrendsViewModel              // 数据加载 + 窗口切换
    @Environment(\.theme) private var theme                     // 当前主题色板（渐变 / 图表配色）

    // ── Body ──
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                switch appState.syncState {
                case .noAccount:
                    EmptyStateView(icon: "person.crop.circle.badge.exclamationmark",
                        title: loc(L10n.Dashboard.noAccountTitle),
                        message: loc(L10n.Dashboard.noAccountMessage),
                        actionLabel: nil, action: nil)
                case .dataReady:
                    ScrollView {
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error,
                                onDismiss: { viewModel.errorMessage = nil }, onRetry: nil)
                                .padding(.top, 8)
                        }
                        VStack(spacing: 12) {
                            timeWindowPicker
                        /// 六个统计图表卡片 — 每张可点击进入详情页
                        ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                            let points = viewModel.chartData(for: metricType)
                            NavigationLink {
                                TrendDetailView(
                                    metricType: metricType,
                                    dataPoints: points,
                                    timeWindow: viewModel.selectedWindow,
                                    barGradientStart: theme.chartBarGradientStart,
                                    barGradientEnd: theme.chartBarGradientEnd
                                )
                            } label: {
                                TrendChart(
                                    dataPoints: points,
                                    barGradientStart: theme.chartBarGradientStart,
                                    barGradientEnd: theme.chartBarGradientEnd,
                                    title: metricType.localizedName,
                                    timeWindow: viewModel.selectedWindow
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollContentBackground(.hidden)
                case .syncing:
                    ProgressView(loc(L10n.Common.loading)).frame(maxWidth: .infinity, minHeight: 300)
                case .readyToSync:
                    EmptyStateView(icon: "arrow.triangle.2.circlepath",
                        title: loc(L10n.Dashboard.noDataTitle),
                        message: loc(L10n.Dashboard.noDataMessage),
                        actionLabel: loc(L10n.Common.syncNow),
                        action: { /* sync from Dashboard */ })
                }
            }
            .navigationTitle(loc(L10n.Trends.title))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // 首次加载：从 AppState 读取全局选中账户
            await viewModel.loadInitialAccount()
            if let id = appState.selectedAccountId ?? viewModel.selectedAccountId {
                await viewModel.loadTrends(accountId: id)
            }
        }
        .onChange(of: appState.syncState) { _, new in
            if new == .dataReady, let id = appState.selectedAccountId ?? viewModel.selectedAccountId {
                Task { await viewModel.loadTrends(accountId: id) }
            }
        }
        // Dashboard 切换账户 → 全局 AppState.selectedAccountId 变化 → 本页重新加载
        .onChange(of: appState.selectedAccountId) { _, newId in
            guard let id = newId else { return }
            Task { await viewModel.loadTrends(accountId: id) }
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

}
