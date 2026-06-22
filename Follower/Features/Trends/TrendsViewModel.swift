//
//  TrendsViewModel.swift
//  Follower
//
//  Lambda-2: 多指标竖条柱状图 ViewModel。
//  一次 fetch 全部 metricType，内存分区，日/周/月切换零延迟。
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {

    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol

    static let visibleMetricTypes: [MetricType] = [
        .followerGrowth, .engagementTrend, .averageLikes,
        .averageComments, .averageShares, .profileViews
    ]

    @Published var dailyMetrics: [MetricType: [Metric]] = [:]
    @Published var weeklyMetrics: [MetricType: [Metric]] = [:]
    @Published var monthlyMetrics: [MetricType: [Metric]] = [:]
    @Published var selectedWindow: TimeWindow = .day
    @Published var selectedAccountId: Int64?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
    }

    func loadInitialAccount() async {
        do {
            let accounts = try await accountRepo.fetchAll()
            #if DEBUG
            print("[TrendsVM] loadInitialAccount: \(accounts.count) accounts, firstId=\(accounts.first?.id ?? -1)")
            #endif
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
            if let id = selectedAccountId {
                await loadTrends(accountId: id)
            } else {
                #if DEBUG
                print("[TrendsVM] ⚠️ selectedAccountId is nil, loadTrends NOT called")
                #endif
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func loadTrends(accountId: Int64) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var dayDict: [MetricType: [Metric]] = [:]
            var weekDict: [MetricType: [Metric]] = [:]
            var monthDict: [MetricType: [Metric]] = [:]

            for type in Self.visibleMetricTypes {
                let d = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .day, limit: 90)
                let w = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .week, limit: 52)
                let m = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .month, limit: 24)
                #if DEBUG
                print("[\(type)] day:", d.prefix(3).map { ($0.observedAt, $0.value) })
                #endif
                if !d.isEmpty { dayDict[type] = d }
                if !w.isEmpty { weekDict[type] = w }
                if !m.isEmpty { monthDict[type] = m }
            }

            dailyMetrics = dayDict
            weeklyMetrics = weekDict
            monthlyMetrics = monthDict
            #if DEBUG
            print("[TrendsVM] loadTrends done — dayTypes=\(dayDict.count) weekTypes=\(weekDict.count) monthTypes=\(monthDict.count)")
            print("[TrendsVM] followerGrowth day sample: \(chartData(for: .followerGrowth).prefix(3).map { ($0.date, $0.value) })")
            #endif
        } catch { errorMessage = error.localizedDescription }
    }

    func selectWindow(_ window: TimeWindow) { selectedWindow = window }

    func chartData(for metricType: MetricType) -> [TrendDataPoint] {
        let dict: [MetricType: [Metric]]
        switch selectedWindow {
        case .day: dict = dailyMetrics
        case .week: dict = weeklyMetrics
        case .month: dict = monthlyMetrics
        }
        return dict[metricType]?
            .sorted { $0.observedAt < $1.observedAt }
            .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }
            ?? []
    }

}

struct TrendDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
