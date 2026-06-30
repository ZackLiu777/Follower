//
//  TrendsViewModel.swift
//  Follower
//
//  Sigma: 多指标竖条柱状图 ViewModel。基于 Lambda 已验证数据流扩展年级。
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
    @Published var yearlyMetrics: [MetricType: [Metric]] = [:]
    @Published var hourlyData: [MetricType: [TrendDataPoint]] = [:]
    @Published var selectedWindow: TimeWindow = .day
    @Published var selectedAccountId: Int64?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(snapshotRepo: SnapshotRepositoryProtocol, metricRepo: MetricRepositoryProtocol, accountRepo: AccountRepositoryProtocol) {
        self.snapshotRepo = snapshotRepo; self.metricRepo = metricRepo; self.accountRepo = accountRepo
    }

    func loadInitialAccount() async {
        do {
            let accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
            if let id = selectedAccountId { await loadTrends(accountId: id) }
            if selectedWindow == .day { await generateHourlyData() }
        } catch { errorMessage = error.localizedDescription }
    }

    func loadTrends(accountId: Int64) async {
        isLoading = true; defer { isLoading = false }
        do {
            var dayDict: [MetricType: [Metric]] = [:]
            var weekDict: [MetricType: [Metric]] = [:]
            var monthDict: [MetricType: [Metric]] = [:]
            var yearDict: [MetricType: [Metric]] = [:]

            for type in Self.visibleMetricTypes {
                let d = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .day, limit: 90)
                let w = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .week, limit: 52)
                let m = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .month, limit: 24)
                let y = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .year, limit: 10)
                if !d.isEmpty { dayDict[type] = d }
                if !w.isEmpty { weekDict[type] = w }
                if !m.isEmpty { monthDict[type] = m }
                if !y.isEmpty { yearDict[type] = y }
            }

            dailyMetrics = dayDict; weeklyMetrics = weekDict
            monthlyMetrics = monthDict; yearlyMetrics = yearDict
        } catch { errorMessage = error.localizedDescription }
    }

    /// Day 窗口：基于最新日 Snapshot 实时生成 24 小时假数据（不持久化）
    func generateHourlyData() async {
        guard let accountId = selectedAccountId,
              let snap = try? await snapshotRepo.latest(accountId: accountId) else {
            hourlyData = mockHourly()
            return
        }
        var dict: [MetricType: [TrendDataPoint]] = [:]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for type in Self.visibleMetricTypes {
            let baseVal: Double = switch type {
            case .followerGrowth: Double(snap.followersCount)
            case .engagementTrend: snap.engagementRate * 100
            case .averageLikes: Double(snap.totalLikes)
            case .averageComments: Double(snap.totalComments)
            case .averageShares: Double(snap.totalShares)
            case .profileViews: Double(snap.totalViews)
            default: 0
            }
            var points: [TrendDataPoint] = []
            for h in 0..<24 {
                let date = calendar.date(byAdding: .hour, value: h, to: today) ?? today
                let v = Double.random(in: -baseVal * 0.03 ... baseVal * 0.05)
                points.append(TrendDataPoint(date: date, value: max(0, baseVal + v)))
            }
            dict[type] = points
        }
        hourlyData = dict
    }

    /// 无 Snapshot 时的纯 mock 24 小时数据
    private func mockHourly() -> [MetricType: [TrendDataPoint]] {
        var dict: [MetricType: [TrendDataPoint]] = [:]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for type in Self.visibleMetricTypes {
            let base = Double(abs(type.localizedName.hashValue) % 800 + 300)
            var points: [TrendDataPoint] = []
            for h in 0..<24 {
                let date = calendar.date(byAdding: .hour, value: h, to: today) ?? today
                let v = Double.random(in: -base * 0.15 ... base * 0.25)
                points.append(TrendDataPoint(date: date, value: max(0, base + v)))
            }
            dict[type] = points
        }
        return dict
    }

    func selectWindow(_ window: TimeWindow) async {
        selectedWindow = window
        if window == .day { await generateHourlyData() }
    }
    
    func chartData(for metricType: MetricType) -> [TrendDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedWindow {
        case .day:
            return hourlyData[metricType] ?? []

        case .week:
            var cal = calendar
            cal.firstWeekday = 2  // Monday — 与 TrendChart.startOfWeek 完全一致
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let weekStart = cal.date(from: comps) ?? calendar.startOfDay(for: now)

            // ★ 用 dailyMetrics（日数据），不是 weeklyMetrics（周聚合）
            let raw = dailyMetrics[metricType] ?? []

            return (0..<7).map { i in
                let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart)!
                let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart
                let value = raw
                    .first { calendar.isDate($0.observedAt, inSameDayAs: dayStart) }?
                    .value ?? 0
                return TrendDataPoint(date: noon, value: value)
            }

        case .month:
            return (monthlyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }

        case .year:
            return (yearlyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }
        }
    }
}

struct TrendDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
