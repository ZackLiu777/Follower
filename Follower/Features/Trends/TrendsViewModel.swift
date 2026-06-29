//
//  TrendsViewModel.swift
//  Follower
//
//  Sigma: TimeSeriesEngine 驱动。单 raw 缓存 + bucket 聚合。
//

import Foundation
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

    /// 原始日/月级 Metric 缓存，按 metricType 分组
    @Published var rawMetrics: [MetricType: [Metric]] = [:]
    /// Day 窗口的 24 小时实时生成数据（不持久化）
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
        } catch { errorMessage = error.localizedDescription }
    }

    func loadTrends(accountId: Int64) async {
        isLoading = true; defer { isLoading = false }
        do {
            var dict: [MetricType: [Metric]] = [:]
            for type in Self.visibleMetricTypes {
                let day = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .day, limit: 31)
                let month = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .month, limit: 12)
                dict[type] = day + month
            }
            rawMetrics = dict
        } catch { errorMessage = error.localizedDescription }
    }

    /// Day 窗口：基于最新日 Snapshot 实时生成 24 小时数据
    func generateHourlyData() async {
        guard let accountId = selectedAccountId,
              let snap = try? await snapshotRepo.latest(accountId: accountId) else { return }
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

    func selectWindow(_ window: TimeWindow) {
        selectedWindow = window
        if window == .day { Task { await generateHourlyData() } }
    }

    /// 统一入口：raw metrics → TimeSeriesEngine bucket → chart data
    func chartData(for metricType: MetricType) -> [TrendDataPoint] {
        switch selectedWindow {
        case .day:
            return hourlyData[metricType] ?? []
        case .week:
            return TimeSeriesEngine.aggregate(rawMetrics[metricType] ?? [], bucket: .day).suffix(7)
        case .month:
            return TimeSeriesEngine.aggregate(rawMetrics[metricType] ?? [], bucket: .day).suffix(31)
        case .year:
            return TimeSeriesEngine.aggregate(rawMetrics[metricType] ?? [], bucket: .year)
        }
    }
}

struct TrendDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
