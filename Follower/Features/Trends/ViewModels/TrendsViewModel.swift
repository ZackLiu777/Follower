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
    /// 日窗口真实采样点来源：今天 0–24h 内的 profileSnapshot Event
    private let eventRepo: EventRepositoryProtocol

    /// 图表中展示的四个指标类型，顺序固定
    /// v0.11：互动率已从图表移除；v0.14：浏览（profileViews）已从图表移除
    /// （Instagram API 无可用浏览指标数据源，恒 0）。
    /// 两者数据生成均保留 — 决策引擎 / MediaKit / Premium 仍依赖。
    static let visibleMetricTypes: [MetricType] = [
        .followerGrowth, .averageLikes,
        .averageComments, .averageShares
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

    /// 同步完成通知监听器（Dashboard 同步后刷新趋势数据）。
    /// nonisolated(unsafe)：deinit 为 nonisolated 上下文，observer 只是引用句柄，
    /// 跨隔离访问安全（注册/移除均在 init/deinit 内各一次）
    nonisolated(unsafe) private var syncObserver: NSObjectProtocol?

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
    init(
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        accountRepo: AccountRepositoryProtocol,
        eventRepo: EventRepositoryProtocol
    ) {
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.accountRepo = accountRepo
        self.eventRepo = eventRepo
        // v0.15：监听同步完成通知 — Dashboard 同步后重新加载趋势数据。
        // TabView 中 VM 存活，仅靠 View 的 .task 首次加载会错过同步后的新观测，
        // 日窗口会一直显示同步前的空态（"No trend data yet"）。
        syncObserver = NotificationCenter.default.addObserver(
            forName: .syncCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reloadAfterSync() }
        }
    }

    deinit {
        if let syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
    }

    /// 同步完成后刷新当前账号趋势数据（幂等：无选中账号或数据未变时无害重载）
    private func reloadAfterSync() async {
        guard let accountId = selectedAccountId else { return }
        await loadTrends(accountId: accountId)
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
                // v1.1 放开 90 天限制：日窗口拉 365 天，周/月/年保持长期聚合
                let d = try await metricRepo.fetch(accountId: accountId, metricType: type, window: .day, limit: 365)
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

        // 首次进入默认窗口为 .day — 需在加载时触发一次真实采样点生成
        if selectedWindow == .day { await generateHourlyData() }
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
            // 月窗口 = 当月内日粒度真实值（不含平均数）
            result = (dailyMetrics[metricType] ?? [])
                .filter { calendar.isDate($0.observedAt, equalTo: now, toGranularity: .month) }
                .sorted { $0.observedAt < $1.observedAt }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }

        case .year:
            // 年窗口 = 所选年份的 12 根月柱（月指标 = 月末真实值）
            result = (monthlyMetrics[metricType] ?? [])
                .filter { calendar.component(.year, from: $0.observedAt) == selectedYear }
                .sorted { $0.observedAt < $1.observedAt }
                .map { TrendDataPoint(date: $0.observedAt, value: $0.value) }
        }
        return result
    }

    // MARK: - 总计 / 增减 / 周期标签

    /// 总览页增减：
    /// - day：今天采样点相邻差（不足 2 点回退日粒度 Metric）
    /// - week/month/year：各自窗口的周期末值序列相邻两条（周 vs 上周 / 月 vs 上月 / 年 vs 去年）
    ///   —— 各窗口显示各自粒度的变化，不再共用日粒度相邻差（修复各窗口同值的 bug）。
    ///   周期末值由聚合层 periodEndMetrics 生成（组内最后一次真实观测，无 0 占位）。
    func delta(for metricType: MetricType) -> Int {
        switch selectedWindow {
        case .day:
            let hourly = hourlyData[metricType] ?? []
            if hourly.count >= 2 {
                return Int(hourly[hourly.count - 1].value - hourly[hourly.count - 2].value)
            }
            // 今天只有一次观测 → 回退日粒度 Metric（真实值，无 0 占位）
            let daily = (dailyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
            guard daily.count >= 2 else { return 0 }
            return daily[daily.count - 1].value - daily[daily.count - 2].value
        case .week, .month, .year:
            let series: [Metric]
            switch selectedWindow {
            case .week:  series = weeklyMetrics[metricType] ?? []
            case .month: series = monthlyMetrics[metricType] ?? []
            default:     series = yearlyMetrics[metricType] ?? []
            }
            let sorted = series.sorted { $0.observedAt < $1.observedAt }
            if sorted.count >= 2 {
                return sorted[sorted.count - 1].value - sorted[sorted.count - 2].value
            }
            // 高窗口无数据 → 回退日粒度相邻两条
            let daily = (dailyMetrics[metricType] ?? []).sorted { $0.observedAt < $1.observedAt }
            guard daily.count >= 2 else { return 0 }
            return daily[daily.count - 1].value - daily[daily.count - 2].value
        }
    }

    /// 详情页总计：窗口内最新真实值（柱高/点为绝对值，求和无意义 — v0.09）。
    /// 例：日窗口粉丝采样 2 → 5，显示 5（当前真实粉丝数），而非 2+5=7。
    func totalValue(for metricType: MetricType, in window: TimeWindow) -> Int {
        Int(chartData(for: metricType, in: window).last?.value ?? 0)
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

    /// 日视图：今天 0–24h 内的真实同步采样点（每次同步写入的 profileSnapshot Event）。
    /// 无事件时返回空数组 — 图表显示空态，不伪造数据。
    func generateHourlyData() async {
        guard let accountId = selectedAccountId else {
            hourlyData = [:]
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let events = (try? await eventRepo.fetch(accountId: accountId, from: today, to: tomorrow)) ?? []

        // 仅取 profileSnapshot 事件，保留精确观测时间（observedAt 到秒）
        let samples: [(observedAt: Date, profile: APIProfileResponse)] = events.compactMap { event in
            guard event.eventType == .profileSnapshot,
                  let profile = try? JSONDecoder().decode(APIProfileResponse.self, from: event.payload)
            else { return nil }
            return (event.observedAt, profile)
        }
        guard !samples.isEmpty else { hourlyData = [:]; return }

        var dict: [MetricType: [TrendDataPoint]] = [:]
        for type in Self.visibleMetricTypes {
            let points = samples.map { sample -> TrendDataPoint in
                let value: Int = switch type {
                case .followerGrowth: sample.profile.followersCount
                case .averageLikes: sample.profile.totalLikes
                case .averageComments: sample.profile.totalComments
                case .averageShares: sample.profile.totalShares
                default: 0
                }
                return TrendDataPoint(date: sample.observedAt, value: value)
            }
            // v0.09：每个指标独立显示「值的变化」——该指标值未变化的采样点跳过
            // （评论变了但粉丝没变 → 粉丝曲线不新增点）。事件表所有观测原样保留，
            // 只是曲线生成粒度 = 指标状态变化，而非每次同步。
            // v0.10：先按小时桶合并（图表 x 轴为小时刻度，同一小时内多根柱会重叠显示），
            // 再做同值过滤。
            dict[type] = Self.changedPoints(Self.hourlyBuckets(points))
        }
        hourlyData = dict
    }

    /// 按小时桶合并：每小时只保留最后一次观测（柱状图 x 轴为小时刻度，
    /// 同一小时内多个点会画在同一柱位重叠显示 — v0.10）。
    /// 输入任意顺序；输出按时间升序。每个保留的点都是真实观测值。
    nonisolated static func hourlyBuckets(_ points: [TrendDataPoint]) -> [TrendDataPoint] {
        let calendar = Calendar.current
        var byHour: [Date: TrendDataPoint] = [:]
        for point in points.sorted(by: { $0.date < $1.date }) {
            let hourStart = calendar.dateInterval(of: .hour, for: point.date)?.start ?? point.date
            byHour[hourStart] = point // 后到覆盖 → 每桶保留该小时最后一次观测
        }
        return byHour.values.sorted { $0.date < $1.date }
    }

    /// 只保留「值发生变化」的采样点（首个点 + 变化点）；同值点跳过（保留首次出现的时间）。
    /// 纯函数，不访问实例状态 → nonisolated 供测试直接调用。
    nonisolated static func changedPoints(_ points: [TrendDataPoint]) -> [TrendDataPoint] {
        var result: [TrendDataPoint] = []
        for point in points {
            guard let last = result.last else {
                result.append(point)
                continue
            }
            if point.value != last.value { result.append(point) }
        }
        return result
    }

    /// 切换时间窗 — day 窗口时按小时均分
    func selectWindow(_ window: TimeWindow) async {
        selectedWindow = window
        if window == .day { await generateHourlyData() }
    }
}
