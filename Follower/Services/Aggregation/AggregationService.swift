//
//  AggregationService.swift
//  Follower
//
//  聚合服务，负责：
//  - 由 Event 生成 Snapshot
//  - 由 Snapshot 生成 Metric
//  - 处理后台增量计算
//  - 避免在主线程执行重计算
//

import Foundation

// MARK: - AggregationResult

/// 聚合操作的返回结果：Snapshot 和 Metric 的更新计数
struct AggregationResult {
    let snapshotsUpdated: Int
    let metricsUpdated: Int
}

// MARK: - AggregationServiceProtocol

/// 聚合服务协议：Event → Snapshot → Metric 的转换管道
protocol AggregationServiceProtocol: Sendable {
    /// 对指定时间范围的 Event 执行聚合，生成 Snapshot 和 Metric
    func aggregate(accountId: Int64, from: Date, to: Date) async throws -> AggregationResult
    /// 重新计算所有 Snapshot（全量重建）
    func rebuildAll(accountId: Int64) async throws -> AggregationResult
}

// MARK: - AggregationService

/// 聚合服务实现：将原始 Event 按日/周/月/年聚合为 Snapshot 和 Metric
final class AggregationService: AggregationServiceProtocol {
    private let eventRepo: EventRepositoryProtocol
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol

    /// 注入 Event / Snapshot / Metric 三个 Repository
    init(
        eventRepo: EventRepositoryProtocol,
        snapshotRepo: SnapshotRepositoryProtocol,
        metricRepo: MetricRepositoryProtocol
    ) {
        self.eventRepo = eventRepo
        self.snapshotRepo = snapshotRepo
        self.metricRepo = metricRepo
    }

    /// 增量聚合：读取时间范围内的 Event，生成 Snapshot 和 Metric。
    /// 只对受影响的日期范围计算 Metric，避免每次全量重算所有历史数据。
    func aggregate(accountId: Int64, from: Date, to: Date) async throws -> AggregationResult {
        let events = try await eventRepo.fetch(accountId: accountId, from: from, to: to)

        // 1. Event → Snapshot（按天分组）
        let snapshots = buildSnapshots(accountId: accountId, events: events)
        _ = try await snapshotRepo.upsertBatch(snapshots)

        // 2. 增量计算 Metric
        let calendar = Calendar.current
        let extendedFrom = calendar.date(byAdding: .month, value: -1, to: from) ?? from
        let extendedTo = calendar.date(byAdding: .month, value: 1, to: to) ?? to
        let affectedSnapshots = try await snapshotRepo.fetch(accountId: accountId, from: extendedFrom, to: extendedTo)
        let metrics = buildMetrics(accountId: accountId, snapshots: affectedSnapshots)
        _ = try await metricRepo.upsertBatch(metrics)

        return AggregationResult(
            snapshotsUpdated: snapshots.count,
            metricsUpdated: metrics.count
        )
    }

    /// 全量重建：清空旧 Metric 后重新聚合所有历史 Event
    func rebuildAll(accountId: Int64) async throws -> AggregationResult {
        // 先清掉所有旧 Metric（含之前错误 0 值数据）
        _ = try await metricRepo.deleteOldMetrics(accountId: accountId, olderThan: Date.distantFuture)

        let allEvents = try await eventRepo.fetchAll(accountId: accountId)
        let snapshots = buildSnapshots(accountId: accountId, events: allEvents)
        _ = try await snapshotRepo.upsertBatch(snapshots)

        let allSnapshots = try await snapshotRepo.fetchAll(accountId: accountId)
        let metrics = buildMetrics(accountId: accountId, snapshots: allSnapshots)
        _ = try await metricRepo.upsertBatch(metrics)

        return AggregationResult(
            snapshotsUpdated: snapshots.count,
            metricsUpdated: metrics.count
        )
    }

    // MARK: - Private Computation

    /// 由 Event 构建 Snapshot：按 accountId + observedAt(天) 分组聚合
    private func buildSnapshots(accountId: Int64, events: [Event]) -> [Snapshot] {
        let calendar = Calendar.current
        // 先按时间排序，保证 profileSnapshot 不会在 followerChange 之前被覆盖
        let sorted = events.sorted { $0.observedAt < $1.observedAt }
        var grouped: [Date: (followers: Int, following: Int, media: Int, likes: Int, comments: Int, shares: Int, views: Int, engagementRate: Double, count: Int)] = [:]

        for event in sorted {
            let day = calendar.startOfDay(for: event.observedAt)
            var cur = grouped[day] ?? (0, 0, 0, 0, 0, 0, 0, 0, 0)

            switch event.eventType {
            case .profileSnapshot:
                if let profile = try? JSONDecoder().decode(APIProfileResponse.self, from: event.payload) {
                    cur.followers = profile.followersCount
                    cur.following = profile.followingCount
                    cur.media = profile.mediaCount
                    cur.likes = profile.totalLikes
                    cur.comments = profile.totalComments
                    cur.shares = profile.totalShares
                    cur.views = profile.totalViews
                    cur.engagementRate = profile.engagementRate
                }
            case .followerChange:
                if let point = try? JSONDecoder().decode(APITrendDataPoint.self, from: event.payload) {
                    cur.followers = point.followersCount
                    cur.following = point.followingCount
                    cur.media = point.mediaCount
                    cur.views = point.totalViews
                    cur.engagementRate = point.engagementRate
                    // 互动明细：数据源缺失（真实 API / 旧 event）→ nil → 保持原值 0
                    if let likes = point.likesCount { cur.likes = likes }
                    if let comments = point.commentsCount { cur.comments = comments }
                    if let shares = point.sharesCount { cur.shares = shares }
                }
            default:
                break
            }
            cur.count += 1
            grouped[day] = cur
        }

        return grouped.map { (day, values) in
            Snapshot(
                accountId: accountId,
                followersCount: values.followers,
                followingCount: values.following,
                mediaCount: values.media,
                engagementRate: values.engagementRate,
                totalLikes: values.likes,
                totalComments: values.comments,
                totalShares: values.shares,
                totalViews: values.views,
                observedAt: day,
                createdAt: Date()
            )
        }
    }

    /// 由 Snapshot 计算 Metric：日窗口取快照真实值（整数直通），周/月/年窗口取周期末值（组内最后一次真实快照），不使用平均数。
    private func buildMetrics(accountId: Int64, snapshots: [Snapshot]) -> [Metric] {
        let calendar = Calendar.current
        var metrics: [Metric] = []

        // Day metrics：每个 Snapshot 一组 6 项真实值
        for snapshot in snapshots {
            metrics.append(contentsOf: Self.dayMetrics(accountId: accountId, snapshot: snapshot))
        }

        // Week / Month / Year metrics：周期末值（组内 observedAt 最大的快照的真实值）
        metrics.append(contentsOf: Self.periodEndMetrics(
            accountId: accountId, snapshots: snapshots, window: .week,
            periodStart: { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }
        ))
        metrics.append(contentsOf: Self.periodEndMetrics(
            accountId: accountId, snapshots: snapshots, window: .month,
            periodStart: { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) }
        ))
        metrics.append(contentsOf: Self.periodEndMetrics(
            accountId: accountId, snapshots: snapshots, window: .year,
            periodStart: { calendar.date(from: calendar.dateComponents([.year], from: $0)) }
        ))

        return metrics
    }

    /// 单个 Snapshot 的 6 项日指标 — 全部整数：计数类直通快照值，互动率为万分比整数
    static func dayMetrics(accountId: Int64, snapshot: Snapshot) -> [Metric] {
        let e = engagementBasis(snapshot.engagementRate)
        let createdAt = Date()
        return [
            Metric(accountId: accountId, metricType: .followerGrowth, value: snapshot.followersCount, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
            Metric(accountId: accountId, metricType: .engagementTrend, value: e, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
            Metric(accountId: accountId, metricType: .averageLikes, value: snapshot.totalLikes, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
            Metric(accountId: accountId, metricType: .averageComments, value: snapshot.totalComments, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
            Metric(accountId: accountId, metricType: .averageShares, value: snapshot.totalShares, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
            Metric(accountId: accountId, metricType: .profileViews, value: snapshot.totalViews, window: .day, observedAt: snapshot.observedAt, createdAt: createdAt),
        ]
    }

    /// 周期末值聚合 — 每个时间窗组内取 observedAt 最大的真实快照，其 6 项值作为该周期指标。
    /// 输入 snapshots 按时间升序遍历，后到者覆盖 → 组内保留最后一次真实观测。
    static func periodEndMetrics(
        accountId: Int64, snapshots: [Snapshot], window: TimeWindow,
        periodStart: (Date) -> Date?
    ) -> [Metric] {
        var latest: [Date: Snapshot] = [:]  // periodStart → 组内最新快照
        for snapshot in snapshots.sorted(by: { $0.observedAt < $1.observedAt }) {
            guard let start = periodStart(snapshot.observedAt) else { continue }
            latest[start] = snapshot
        }
        var metrics: [Metric] = []
        for (start, snapshot) in latest {
            let day = dayMetrics(accountId: accountId, snapshot: snapshot)
            metrics.append(contentsOf: day.map { m in
                Metric(accountId: accountId, metricType: m.metricType, value: m.value,
                       window: window, observedAt: start, createdAt: Date())
            })
        }
        return metrics
    }

    /// 互动率万分比换算：0.0543 → 543（整数存储，杜绝浮点失真）
    static func engagementBasis(_ rate: Double) -> Int {
        Int((rate * 10000).rounded())
    }
}
