//
//  TrendsView.swift
//  Follower
//
//  Sigma: 趋势统计图表页。
//

import SwiftUI

struct TrendsView: View {

    @Environment(AppState.self) private var appState
    @Bindable var viewModel: TrendsViewModel
    @Environment(\.theme) private var theme

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
                        ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                            let points = viewModel.chartData(for: metricType)
                            NavigationLink {
                                TrendDetailView(
                                    viewModel: viewModel,
                                    metricType: metricType,
                                    barGradientStart: theme.chartBarGradientStart,
                                    barGradientEnd: theme.chartBarGradientEnd
                                )
                            } label: {
                                TrendChart(
                                    dataPoints: points,
                                    barGradientStart: theme.chartBarGradientStart,
                                    barGradientEnd: theme.chartBarGradientEnd,
                                    title: metricType.localizedName,
                                    timeWindow: viewModel.selectedWindow,
                                    delta: viewModel.delta(for: metricType)
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
            await viewModel.loadInitialAccount()
            if let id = appState.selectedAccountId ?? viewModel.selectedAccountId {
                await viewModel.loadTrends(accountId: id)
            }
        }
        .onChange(of: appState.selectedAccountId) { _, newId in
            guard let id = newId else { return }
            Task { await viewModel.loadTrends(accountId: id) }
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: theme.backgroundGradientColors,
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()
    }

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
