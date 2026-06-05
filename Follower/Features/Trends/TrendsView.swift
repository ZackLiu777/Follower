//
//  TrendsView.swift
//  Follower
//
//  历史趋势页面。数据均由 ViewModel 提供，View 不做计算和直接数据访问。
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TrendsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    metricTypePicker
                    timeWindowPicker

                    TrendChart(
                        dataPoints: viewModel.trendDataPoints,
                        lineColor: chartColor,
                        title: chartTitle
                    )
                    .padding(.horizontal)

                    if let first = viewModel.trendDataPoints.first,
                       let last = viewModel.trendDataPoints.last,
                       viewModel.trendDataPoints.count > 1 {
                        growthSummary(first: first, last: last)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Trends")
        }
        .task {
            await viewModel.loadInitialAccount()
        }
    }

    // MARK: - Pickers

    private var metricTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleMetricTypes, id: \.self) { type in
                    Button {
                        viewModel.selectMetricType(type)
                    } label: {
                        Text(type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
        Picker("Time Window", selection: $viewModel.selectedWindow) {
            ForEach(TimeWindow.allCases, id: \.self) { window in
                Text(window.displayName).tag(window)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Growth Summary

    private func growthSummary(first: TrendDataPoint, last: TrendDataPoint) -> some View {
        let change = last.value - first.value
        let pct = first.value > 0 ? (change / first.value) * 100 : 0

        return HStack(spacing: 16) {
            summaryItem(label: "Change", value: String(format: "%+.0f", change), isPositive: change >= 0)
            summaryItem(label: "Growth", value: String(format: "%+.1f%%", pct), isPositive: pct >= 0)
        }
        .padding(.horizontal)
    }

    private func summaryItem(label: String, value: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(isPositive ? .green : .red)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

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
        "\(viewModel.selectedMetricType.displayName) — \(viewModel.selectedWindow.displayName)"
    }
}

// MARK: - Display Helpers

extension MetricType {
    var displayName: String {
        switch self {
        case .followerGrowth: return "Followers"
        case .engagementTrend: return "Engagement"
        case .averageLikes: return "Likes"
        case .averageComments: return "Comments"
        case .averageShares: return "Shares"
        case .profileViews: return "Views"
        case .reachEstimate: return "Reach"
        }
    }
}

extension TimeWindow: CaseIterable {
    public static var allCases: [TimeWindow] { [.day, .week, .month] }

    var displayName: String {
        switch self {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        }
    }
}

// MARK: - Preview

#Preview {
    TrendsView(viewModel: TrendsViewModel(
        snapshotRepo: PreviewMocks.snapshotRepo,
        metricRepo: PreviewMocks.metricRepo,
        accountRepo: PreviewMocks.accountRepo
    ))
    .environmentObject(AppState(databaseManager: DatabaseManager.shared))
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
