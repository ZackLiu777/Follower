//
//  TrendsView.swift
//  Follower
//
//  历史趋势页面。Beta: 全部文案本地化。

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TrendsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil }, onRetry: nil)
                        .padding(.top, 8)
                }
                VStack(spacing: 16) {
                    metricTypePicker
                    timeWindowPicker
                    TrendChart(dataPoints: viewModel.trendDataPoints, lineColor: chartColor, title: chartTitle)
                        .padding(.horizontal)
                    if let first = viewModel.trendDataPoints.first,
                       let last = viewModel.trendDataPoints.last,
                       viewModel.trendDataPoints.count > 1 {
                        growthSummary(first: first, last: last)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(loc(L10n.Trends.title))
        }
        .task { await viewModel.loadInitialAccount() }
    }

    private var metricTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleMetricTypes, id: \.self) { type in
                    Button { viewModel.selectMetricType(type) } label: {
                        Text(type.localizedName)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(viewModel.selectedMetricType == type ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial))
                            .foregroundColor(viewModel.selectedMetricType == type ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var timeWindowPicker: some View {
        Picker("Time Window", selection: Binding(
            get: { viewModel.selectedWindow },
            set: { viewModel.selectWindow($0) }
        )) {
            Text(loc(L10n.Trends.daily)).tag(TimeWindow.day)
            Text(loc(L10n.Trends.weekly)).tag(TimeWindow.week)
            Text(loc(L10n.Trends.monthly)).tag(TimeWindow.month)
        }
        .pickerStyle(.segmented).padding(.horizontal)
    }

    private func growthSummary(first: TrendDataPoint, last: TrendDataPoint) -> some View {
        let change = last.value - first.value
        let pct = first.value > 0 ? (change / first.value) * 100 : 0
        return HStack(spacing: 16) {
            summaryItem(label: loc(L10n.Trends.change), value: String(format: "%+.0f", change), isPositive: change >= 0)
            summaryItem(label: loc(L10n.Trends.growth), value: String(format: "%+.1f%%", pct), isPositive: pct >= 0)
        }
        .padding(.horizontal)
    }

    private func summaryItem(label: String, value: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundColor(isPositive ? .green : .red)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var visibleMetricTypes: [MetricType] {
        [.followerGrowth, .engagementTrend, .averageLikes, .averageComments, .averageShares, .profileViews]
    }

    private var chartColor: Color {
        switch viewModel.selectedMetricType {
        case .followerGrowth: return .blue
        case .engagementTrend: return .pink
        case .averageLikes: return .red
        case .averageComments: return .purple
        case .averageShares: return .teal
        case .profileViews: return .indigo
        case .reachEstimate: return .orange
        }
    }

    private var chartTitle: String {
        "\(viewModel.selectedMetricType.localizedName) — \(viewModel.selectedWindow.localizedName)"
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
