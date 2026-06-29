//
//  TrendsView.swift
//  Follower
//
//  Lambda-2: Liquid Glass Trends View
//

import SwiftUI

struct TrendsView: View {

    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TrendsViewModel
    @Environment(\.theme) private var theme

    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack {

                // MARK: Background

                backgroundView

                ScrollView {

                    if let error = viewModel.errorMessage {
                        ErrorBanner(
                            message: error,
                            onDismiss: {
                                viewModel.errorMessage = nil
                            },
                            onRetry: nil
                        )
                        .padding(.top,8)
                    }

                    VStack(spacing:12) {

                        timeWindowPicker

                        ForEach(
                            TrendsViewModel.visibleMetricTypes,
                            id:\.self
                        ) { metricType in

                            TrendChart(
                                dataPoints: viewModel.chartData(for: metricType),
                                barGradientStart: theme.chartBarGradientStart,
                                barGradientEnd: theme.chartBarGradientEnd,
                                title: metricType.localizedName,
                                timeWindow: viewModel.selectedWindow
                            )
                            .padding(.horizontal,12)

                        }

                        if hasAnyData {
                            aggregateGrowthSummary
                        }

                    }
                    .padding(.vertical,8)

                }
                .scrollContentBackground(.hidden)

            }
            .navigationTitle(
                loc(L10n.Trends.title)
            )
        }
        .task {
            await viewModel.loadInitialAccount()
        }
    }

    // MARK: Background

    private var backgroundView: some View {
        LinearGradient(
            colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Time Window Picker

    private var timeWindowPicker: some View {
        Picker("Window", selection: Binding(get: { viewModel.selectedWindow }, set: { viewModel.selectWindow($0) })) {
            ForEach(TimeWindow.allCases, id: \.self) { window in
                Text(window.localizedName).tag(window)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    // MARK: Growth Summary

    private var hasAnyData: Bool {

        TrendsViewModel
            .visibleMetricTypes
            .contains {

                !viewModel
                    .chartData(
                        for:$0
                    )
                    .isEmpty
            }

    }

    private var aggregateGrowthSummary: some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing:8
        ) {

            ForEach(
                TrendsViewModel.visibleMetricTypes,
                id:\.self
            ) { metricType in

                let points =
                viewModel.chartData(
                    for:metricType
                )

                if let first = points.first,
                   let last = points.last,
                   points.count > 1 {

                    let change =
                    last.value-first.value

                    summaryItem(
                        label:
                            metricType.localizedName,
                        value:
                            String(
                                format:"%+.0f",
                                change
                            ),
                        isPositive:
                            change >= 0
                    )

                }
            }
        }
        .padding(.horizontal)
    }

    private func summaryItem(
        label:String,
        value:String,
        isPositive:Bool
    ) -> some View {

        VStack(
            spacing:4
        ) {

            Text(value)
                .font(.headline)
                .foregroundColor(
                    isPositive
                    ? theme.positiveGreen
                    : theme.negativeRed
                )

            Text(label)
                .font(.caption)
                .foregroundColor(
                    theme.textSecondary
                )
        }
        .frame(
            maxWidth:.infinity
        )
        .padding()

        .background(
            .regularMaterial
        )

        .clipShape(
            RoundedRectangle(
                cornerRadius:12
            )
        )
    }
}


// MARK: Extensions

extension MetricType {

    var localizedName:String {

        switch self {

        case .followerGrowth:
            return loc(
                L10n.Trends.followers
            )

        case .engagementTrend:
            return loc(
                L10n.Trends.engagement
            )

        case .averageLikes:
            return loc(
                L10n.Trends.likes
            )

        case .averageComments:
            return loc(
                L10n.Trends.comments
            )

        case .averageShares:
            return loc(
                L10n.Trends.shares
            )

        case .profileViews:
            return loc(
                L10n.Trends.views
            )

        case .reachEstimate:
            return loc(
                L10n.Trends.reach
            )

        default:
            return "\(self)"
        }

    }

}

extension TimeWindow: CaseIterable {

    public static var allCases: [TimeWindow] { [.day, .week, .month, .year] }

    var localizedName: String {
        switch self {
        case .day:   return loc(L10n.Trends.daily)
        case .week:  return loc(L10n.Trends.weekly)
        case .month: return loc(L10n.Trends.monthly)
        case .year:  return loc(L10n.Trends.yearly)
        }
    }

}
