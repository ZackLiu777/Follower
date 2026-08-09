//
//  MediaKitDataProvider.swift
//  Follower
//
//  媒体包数据收集 — 唯一数据入口是 Repository。
//  策略：数据不全不抛错（空序列/空值以 nil 表达），只有账号不存在才 throw，
//  保证媒体包在数据积累初期也能生成（排版负责缺失态展示）。
//

import Foundation

// MARK: - Protocol

protocol MediaKitDataProviding: Sendable {
    func collect(accountId: Int64) async throws -> MediaKitData
}

// MARK: - Provider

struct MediaKitDataProvider: MediaKitDataProviding {
    private let accountRepo: AccountRepositoryProtocol
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol
    private let mediaRepo: MediaPostRepositoryProtocol

    init(
        accountRepo: AccountRepositoryProtocol,
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol,
        mediaRepo: MediaPostRepositoryProtocol
    ) {
        self.accountRepo = accountRepo
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
        self.mediaRepo = mediaRepo
    }

    /// 收集媒体包数据：账号必须存在，其余数据允许缺失
    func collect(accountId: Int64) async throws -> MediaKitData {
        guard let account = try await accountRepo.fetch(id: accountId) else {
            throw MediaKitError.accountNotFound
        }

        let snapshot = try? await snapshotRepo.latest(accountId: accountId)

        return MediaKitData(
            account: account,
            snapshot: snapshot,
            metricRows: await buildMetricRows(accountId: accountId, snapshot: snapshot),
            weeklyGrowth: await fetchWeeklyGrowth(accountId: accountId),
            topPosts: await fetchTopPosts(accountId: accountId),
            postTypeCounts: await fetchPostTypeCounts(accountId: accountId),
            avgLikesSeries: await fetchSeries(accountId: accountId, type: .averageLikes),
            avgCommentsSeries: await fetchSeries(accountId: accountId, type: .averageComments),
            engagementSeries: await fetchSeries(accountId: accountId, type: .engagementTrend),
            trendSeries: await fetchTrendSeries(accountId: accountId),
            weeklySeries: await fetchWeeklySeries(accountId: accountId),
            actionCards: await buildActionCards(accountId: accountId),
            generatedAt: Date()
        )
    }

    // MARK: - Private

    /// 6 行核心指标 + 7 天环比（对照 Dashboard 的 computeDeltas 口径）
    private func buildMetricRows(
        accountId: Int64, snapshot: Snapshot?
    ) async -> [MediaKitMetricRow] {
        guard let snapshot else {
            // 无快照：全部显示占位，不抛错
            return Self.placeholderRows
        }

        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let weekSnapshots = (try? await snapshotRepo.fetch(
            accountId: accountId, from: weekAgo, to: now
        )) ?? []
        let weekAgoSnapshot = weekSnapshots.first

        func pct(_ current: Double, _ past: Double?) -> Double? {
            guard let past, past > 0 else { return nil }
            return (current - past) / past * 100
        }

        return [
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.followers),
                value: Double(snapshot.followersCount),
                formattedValue: formatCompact(Double(snapshot.followersCount)),
                delta: pct(Double(snapshot.followersCount), weekAgoSnapshot.map { Double($0.followersCount) }),
                deltaLabel: deltaText(pct(Double(snapshot.followersCount), weekAgoSnapshot.map { Double($0.followersCount) }))
            ),
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.posts),
                value: Double(snapshot.mediaCount),
                formattedValue: formatCompact(Double(snapshot.mediaCount)),
                delta: pct(Double(snapshot.mediaCount), weekAgoSnapshot.map { Double($0.mediaCount) }),
                deltaLabel: deltaText(pct(Double(snapshot.mediaCount), weekAgoSnapshot.map { Double($0.mediaCount) }))
            ),
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.engagementRate),
                value: snapshot.engagementRate,
                formattedValue: String(format: "%.1f%%", snapshot.engagementRate),
                delta: pct(snapshot.engagementRate, weekAgoSnapshot.map { $0.engagementRate }),
                deltaLabel: deltaText(pct(snapshot.engagementRate, weekAgoSnapshot.map { $0.engagementRate }), isPercent: true)
            ),
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.avgLikes),
                value: Double(snapshot.totalLikes),
                formattedValue: formatCompact(Double(snapshot.totalLikes)),
                delta: pct(Double(snapshot.totalLikes), weekAgoSnapshot.map { Double($0.totalLikes) }),
                deltaLabel: deltaText(pct(Double(snapshot.totalLikes), weekAgoSnapshot.map { Double($0.totalLikes) }))
            ),
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.avgComments),
                value: Double(snapshot.totalComments),
                formattedValue: formatCompact(Double(snapshot.totalComments)),
                delta: pct(Double(snapshot.totalComments), weekAgoSnapshot.map { Double($0.totalComments) }),
                deltaLabel: deltaText(pct(Double(snapshot.totalComments), weekAgoSnapshot.map { Double($0.totalComments) }))
            ),
            MediaKitMetricRow(
                label: loc(L10n.MediaKit.profileViews),
                value: Double(snapshot.totalViews),
                formattedValue: formatCompact(Double(snapshot.totalViews)),
                delta: pct(Double(snapshot.totalViews), weekAgoSnapshot.map { Double($0.totalViews) }),
                deltaLabel: deltaText(pct(Double(snapshot.totalViews), weekAgoSnapshot.map { Double($0.totalViews) }))
            ),
        ]
    }

    /// 12 周粉丝增长（复用聚合层周窗口数据，避免重新聚合）
    private func fetchWeeklyGrowth(accountId: Int64) async -> [MediaKitGrowthPoint] {
        let metrics = (try? await metricRepo.fetch(
            accountId: accountId, metricType: .followerGrowth, window: .week, limit: 12
        )) ?? []
        return metrics
            .sorted { $0.observedAt < $1.observedAt }
            .map { MediaKitGrowthPoint(date: $0.observedAt, followers: $0.value) }
    }

    /// Top 5 帖子：最近 25 条按点赞数降序取前 5
    private func fetchTopPosts(accountId: Int64) async -> [MediaPost] {
        let recent = (try? await mediaRepo.fetchRecent(accountId: accountId, limit: 25)) ?? []
        return recent.sorted { $0.likes > $1.likes }.prefix(5).map { $0 }
    }

    /// 帖子类型分布（最近 100 条统计）
    private func fetchPostTypeCounts(accountId: Int64) async -> [MediaKitPostTypeCount] {
        let recent = (try? await mediaRepo.fetchRecent(accountId: accountId, limit: 100)) ?? []
        let grouped = Dictionary(grouping: recent, by: { $0.type.rawValue })
        return grouped.map { MediaKitPostTypeCount(type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// 日窗口序列（30 天），缺失返回空
    private func fetchSeries(accountId: Int64, type: MetricType) async -> [Double] {
        let metrics = (try? await metricRepo.fetch(
            accountId: accountId, metricType: type, window: .day, limit: 30
        )) ?? []
        return metrics.sorted { $0.observedAt < $1.observedAt }.map { Double($0.value) }
    }

    /// 趋势统计序列（完整模板）：5 指标 × 30 天日窗口（粉丝周序列走 weeklyGrowth）
    private func fetchTrendSeries(accountId: Int64) async -> [MetricType: [Double]] {
        let types: [MetricType] = [
            .averageLikes, .averageComments, .averageShares,
            .engagementTrend, .profileViews,
        ]
        var result: [MetricType: [Double]] = [:]
        for type in types {
            let series = await fetchSeries(accountId: accountId, type: type)
            if !series.isEmpty { result[type] = series }
        }
        return result
    }

    /// 周窗口竖柱状图序列（趋势柱状页）：与趋势页一致的 6 指标 × 最近 7 周
    private func fetchWeeklySeries(accountId: Int64) async -> [MetricType: [Double]] {
        var result: [MetricType: [Double]] = [:]
        for type in TrendsViewModel.visibleMetricTypes {
            let metrics = (try? await metricRepo.fetch(
                accountId: accountId, metricType: type, window: .week, limit: 7
            )) ?? []
            let values = metrics.sorted { $0.observedAt < $1.observedAt }.map { Double($0.value) }
            if !values.isEmpty { result[type] = values }
        }
        return result
    }

    /// 增长决策建议：复用决策引擎流水线（FeatureExtractor → ScoringEngine → CardGenerator），
    /// 与 Decisions 页同源；无快照数据时返回空（决策页跳过）
    private func buildActionCards(accountId: Int64) async -> [ActionCard] {
        let snapshots = (try? await snapshotRepo.fetch(
            accountId: accountId,
            from: Date().addingTimeInterval(-90 * 86_400), to: Date()
        )) ?? []
        guard !snapshots.isEmpty else { return [] }

        let metrics = (try? await metricRepo.fetch(
            accountId: accountId, metricType: .engagementTrend, window: .day, limit: 90
        )) ?? []
        let followers = snapshots.last?.followersCount ?? 0

        let health = FeatureExtractor.extractHealth(snapshots: snapshots, followers: followers)
        let contentPerf = FeatureExtractor.extractContentPerformance(metrics: metrics)
        let timing = FeatureExtractor.extractTimingProfile(metrics: metrics)
        let fatigue = FeatureExtractor.extractFatigue(performance: contentPerf)
        let features = GrowthFeatures(
            contentPerformance: contentPerf, followerHealth: health,
            timingProfile: timing, fatigueIndices: fatigue
        )
        let scores = ScoringEngine.score(features)
        let cards = CardGenerator.generate(scores: scores, features: features)
        return cards.sorted { $0.priority < $1.priority }.prefix(3).map { $0 }
    }

    // MARK: - 占位与格式化

    /// 无快照时的占位行（六行全占位）
    private static var placeholderRows: [MediaKitMetricRow] {
        let labels = [
            loc(L10n.MediaKit.followers), loc(L10n.MediaKit.posts), loc(L10n.MediaKit.engagementRate),
            loc(L10n.MediaKit.avgLikes), loc(L10n.MediaKit.avgComments), loc(L10n.MediaKit.profileViews),
        ]
        return labels.map {
            MediaKitMetricRow(label: $0, value: 0, formattedValue: "—", delta: nil, deltaLabel: "—")
        }
    }

    /// 环比文本：nil → "—"，否则 "+x.x%" / "-x.x%"
    private func deltaText(_ delta: Double?, isPercent: Bool = false) -> String {
        guard let delta else { return "—" }
        let sign = delta >= 0 ? "+" : ""
        let suffix = isPercent ? "%" : "%"
        return "\(sign)\(String(format: "%.1f", delta))\(suffix)"
    }

    /// 万/千缩写（与 Dashboard 共用口径）
    private func formatCompact(_ value: Double) -> String {
        let v = Int(value)
        if v >= 10000 { return String(format: "%.1fw", Double(v) / 10000) }
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000) }
        return "\(v)"
    }
}

// MARK: - Errors

enum MediaKitError: LocalizedError {
    case accountNotFound
    case emptyData       // 无任何页面可生成（防御性兜底）
    case renderFailed    // 渲染页数异常（防御性兜底）

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return loc(L10n.MediaKit.accountNotFound)
        case .emptyData: return "Media Kit has no content to render."
        case .renderFailed: return "Media Kit rendering failed."
        }
    }
}
