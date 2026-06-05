//
//  TrendsViewModel.swift
//  Follower
//
//  历史趋势页面 ViewModel。
//  展示日/周/月趋势、增长与下降变化。
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {
    // MARK: - Dependencies

    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol

    // MARK: - Published State

    @Published var dailyMetrics: [Metric] = []
    @Published var weeklyMetrics: [Metric] = []
    @Published var monthlyMetrics: [Metric] = []

    @Published var selectedMetricType: MetricType = .followerGrowth
    @Published var selectedWindow: TimeWindow = .day

    @Published var trendDataPoints: [TrendDataPoint] = []
    @Published var selectedAccountId: Int64?

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Init

    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
    }

    // MARK: - Public

    /// 加载账号列表并自动选中第一个
    func loadInitialAccount() async {
        do {
            let accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil {
                selectedAccountId = accounts.first?.id
            }
            if let accountId = selectedAccountId {
                await loadTrends(accountId: accountId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTrends(accountId: Int64) async {
        isLoading = true
        defer { isLoading = false }

        do {
            dailyMetrics = try await metricRepo.fetch(
                accountId: accountId,
                metricType: selectedMetricType,
                window: .day,
                limit: 90
            )
            weeklyMetrics = try await metricRepo.fetch(
                accountId: accountId,
                metricType: selectedMetricType,
                window: .week,
                limit: 52
            )
            monthlyMetrics = try await metricRepo.fetch(
                accountId: accountId,
                metricType: selectedMetricType,
                window: .month,
                limit: 24
            )

            buildTrendDataPoints()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectMetricType(_ type: MetricType) {
        selectedMetricType = type
        if let accountId = selectedAccountId {
            Task { await loadTrends(accountId: accountId) }
        }
    }

    func selectWindow(_ window: TimeWindow) {
        selectedWindow = window
        buildTrendDataPoints()
    }

    // MARK: - Private

    /// 由当前选中窗口的 Metric 构建图表数据点
    private func buildTrendDataPoints() {
        let metrics: [Metric]
        switch selectedWindow {
        case .day:   metrics = dailyMetrics
        case .week:  metrics = weeklyMetrics
        case .month: metrics = monthlyMetrics
        }

        trendDataPoints = metrics
            .filter { $0.metricType == selectedMetricType }
            .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - TrendDataPoint

struct TrendDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
