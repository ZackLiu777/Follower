//
//  TrendsView.swift
//  Follower
//
//  Lambda-2: 竖条柱状图趋势页。多指标竖向堆叠 + 增长摘要。
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TrendsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil }, onRetry: nil)
                        .padding(.top, 8)
                }
                VStack(spacing: 12) {
                    timeWindowPicker

                    ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                        TrendChart(
                            dataPoints: viewModel.chartData(for: metricType),
                            barGradientStart: theme.chartBarGradientStart,
                            barGradientEnd: theme.chartBarGradientEnd,
                            title: "\(metricType.localizedName) — \(viewModel.selectedWindow.localizedName)"
                        )
                        .padding(.horizontal)
                    }

                    if hasAnyData { aggregateGrowthSummary }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            }
            .navigationTitle(loc(L10n.Trends.title))
        }
        .task { await viewModel.loadInitialAccount() }
    }

    // MARK: - Picker

    private var timeWindowPicker: some View {
        Picker("Window", selection: Binding(get: { viewModel.selectedWindow }, set: { viewModel.selectWindow($0) })) {
            Text(loc(L10n.Trends.daily)).tag(TimeWindow.day)
            Text(loc(L10n.Trends.weekly)).tag(TimeWindow.week)
            Text(loc(L10n.Trends.monthly)).tag(TimeWindow.month)
        }
        .pickerStyle(.segmented).padding(.horizontal)
    }

    // MARK: - Growth Summary

    private var hasAnyData: Bool {
        TrendsViewModel.visibleMetricTypes.contains { !viewModel.chartData(for: $0).isEmpty }
    }

    private var aggregateGrowthSummary: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(TrendsViewModel.visibleMetricTypes, id: \.self) { metricType in
                let points = viewModel.chartData(for: metricType)
                if let first = points.first, let last = points.last, points.count > 1 {
                    let change = last.value - first.value
                    summaryItem(label: metricType.localizedName, value: String(format: "%+.0f", change), isPositive: change >= 0)
                }
            }
        }
        .padding(.horizontal)
    }

    private func summaryItem(label: String, value: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundColor(isPositive ? theme.positiveGreen : theme.negativeRed)
            Text(label).font(.caption).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension MetricType {
    var localizedName: String {
        switch self {
        case .followerGrowth: return loc(L10n.Trends.followers)
        case .engagementTrend: return loc(L10n.Trends.engagement)
        case .averageLikes: return loc(L10n.Trends.likes)
        case .averageComments: return loc(L10n.Trends.comments)
        case .averageShares: return loc(L10n.Trends.shares)
        case .profileViews: return loc(L10n.Trends.views)
        case .reachEstimate: return loc(L10n.Trends.reach)
        default: return "\(self)"
        }
    }
}

extension TimeWindow: CaseIterable {
    public static var allCases: [TimeWindow] { [.day, .week, .month] }
    var localizedName: String {
        switch self {
        case .day: return loc(L10n.Trends.daily)
        case .week: return loc(L10n.Trends.weekly)
        case .month: return loc(L10n.Trends.monthly)
        }
    }
}

#Preview {
    TrendsView(viewModel: TrendsViewModel(
        snapshotRepo: PreviewMocks.snapshotRepo,
        metricRepo: PreviewMocks.metricRepo,
        accountRepo: PreviewMocks.accountRepo
    )).environmentObject(AppState(databaseManager: DatabaseManager.shared))
}

#if DEBUG
private enum PreviewMocks {
    static let db = DatabaseManager.shared
    static let accountRepo = AccountRepository(db: db)
    static let eventRepo = EventRepository(db: db)
    static let snapshotRepo = SnapshotRepository(db: db)
    static let metricRepo = MetricRepository(db: db)
}
#endif
