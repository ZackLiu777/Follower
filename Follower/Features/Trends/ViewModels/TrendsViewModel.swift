//
//  TrendsViewModel.swift
//  Follower
//
//  Sigma: 多指标竖条柱状图 ViewModel。基于 Lambda 已验证数据流扩展年级。
//

import Foundation
import SwiftUI
import Combine

/// 趋势页 ViewModel — 管理多时间窗指标数据加载、缓存与窗口切换
@MainActor
@Observable
final class TrendsViewModel {

    // ── Repositories ──
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let accountRepo: AccountRepositoryProtocol

    /// 图表中展示的六个指标类型，顺序固定
    static let visibleMetricTypes: [MetricType] = [
        .followerGrowth, .engagementTrend, .averageLikes,
        .averageComments, .averageShares, .profileViews
    ]

    // ── 多窗口指标缓存 ──
     var dailyMetrics: [MetricType: [Metric]] = [:]
     var weeklyMetrics: [MetricType: [Metric]] = [:]
     var monthlyMetrics: [MetricType: [Metric]] = [:]
     var yearlyMetrics: [MetricType: [Metric]] = [:]

    /// 日视图的 24 小时逐时数据（由最新 Snapshot 实时生成）
     var hourlyData: [MetricType: [TrendDataPoint]] = [:]

    // ── UI 状态 ──
     var selectedWindow: TimeWindow = .day
     var selectedAccountId: Int64?
     var isLoading: Bool = false
     var errorMessage: String?

    // ── 年份维度（详情页 year 模式）──
    /// 当前选中年份（详情页 year 窗口切换）
     var selectedYear: Int = Calendar.current.component(.year, from: Date())
    /// 可选年份 — 账号创建年到当前年
     var availableYears: [Int] = []

    // MARK: - 年份范围

    /// 计算可选年份：账号创建年 → 当前年（升序）
    func computeAvailableYears(account: Account?) {
        let nowYear = Calendar.current.component(.year, from: Date())
        guard let account else {
            availableYears = [nowYear]
            selectedYear = nowYear
            return
        }
        let startYear = Calendar.current.component(.year, from: account.createdAt)
        availableYears = Array(startYear...nowYear)
        if !availableYears.contains(selectedYear) {
            selectedYear = nowYear
        }
    }

    /// 依赖注入 Repository，建立数据访问通道
    init(snapshotRepo: SnapshotRepositoryProtocol, metricRepo: MetricRepositoryProtocol, accountRepo: AccountRepositoryProtocol) {
        self.snapshotRepo = snapshotRepo; self.metricRepo = metricRepo; self.accountRepo = accountRepo
    }

    /// 页面首次加载 — 获取首个账号 ID（供 fallback），实际数据由 View 层传入
    func loadInitialAccount() async {
        do {
            let accounts = try await accountRepo.fetchAll()
            if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
        } catch { errorMessage = error.localizedDescription }
    }

    /// 加载指定账号在所有时间窗下的全部指标数据，并清空旧缓存确保数据隔离
    func loadTrends(accountId: Int64) async {
        // 切换账号时清空全部指标缓存，防止旧账号数据残留
        if accountId != selectedAccountId {
            dailyMetrics = [:]; weeklyMetrics = [:]; monthlyMetrics = [:]; yearlyMetrics = [:]; hourlyData = [:]
        }
        selectedAccountId = accountId
        // 计算年份范围（账号创建年 → 当前年）
        let account = try? await accountRepo.fetch(id: accountId)
        computeAvailableYears(account: account)
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

    /// 根据当前时间窗返回指定指标的 TrendDataPoint 数组，供图表渲染
    func chartData(for metricType: MetricType) -> [TrendDataPoint] {
        chartData(for: metricType, in: selectedWindow)
    }

    /// 参数化窗口版 — 详情页独立切换窗口时使用；year 窗口按 selectedYear 过滤
    func chartData(for metricType: MetricType, in window: TimeWindow) -> [TrendDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        let result: [TrendDataPoint]
        switch window {
        case .day:
            result = hourlyData[metricType] ?? []

        case .week:
            // ★ 使用 TrendChart.weeklyDataPoints 共用方法，确保与 Dashboard 数据完全一致
            let raw = dailyMetrics[metricType] ?? []
            result = TrendChart.weeklyDataPoints(from: raw, calendar: calendar, referenceDate: now)

        case .month:
            result = (monthlyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }

        case .year:
            result = (yearlyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
                .filter { Calendar.current.component(.year, from: $0.observedAt) == selectedYear }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }
        }
        return result
    }

    // MARK: - 总计 / 增减 / 周期标签

    /// 总览页增减：窗口内末值 − 首值
    /// day 窗口用日粒度相邻两天（今天 vs 昨天），其余窗口用窗口内首末差
    func delta(for metricType: MetricType) -> Int {
        switch selectedWindow {
        case .day:
            let daily = (dailyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
            guard daily.count >= 2 else { return 0 }
            return Int(daily[daily.count - 1].value - daily[daily.count - 2].value)
        default:
            let points = chartData(for: metricType)
            guard points.count >= 2 else { return 0 }
            return Int(points.last!.value - points.first!.value)
        }
    }

    /// 详情页总计：窗口内直接求和
    func totalValue(for metricType: MetricType, in window: TimeWindow) -> Int {
        chartData(for: metricType, in: window).reduce(0) { $0 + Int($1.value) }
    }

    /// 周期标签（详情页总计下方）：今天 / 本周 / 2026年7月 / 2026
    func periodLabel(for window: TimeWindow) -> String {
        switch window {
        case .day: return loc(L10n.Trends.today)
        case .week: return loc(L10n.Trends.thisWeek)
        case .month: return Date().formatted(.dateTime.year().month())
        case .year: return "\(selectedYear)"
        }
    }

    /// 日视图：基于最新 Snapshot 按 24 小时均分
    func generateHourlyData() async {
        guard let accountId = selectedAccountId,
              let snap = try? await snapshotRepo.latest(accountId: accountId) else {
            hourlyData = [:]
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
            let hourlyValue = max(0, baseVal / 24.0)
            let points = (0..<24).map { h in
                let date = calendar.date(byAdding: .hour, value: h, to: today) ?? today
                return TrendDataPoint(date: date, value: hourlyValue)
            }
            dict[type] = points
        }
        hourlyData = dict
    }

    /// 切换时间窗 — day 窗口时按小时均分
    func selectWindow(_ window: TimeWindow) async {
        selectedWindow = window
        if window == .day { await generateHourlyData() }
    }
}
