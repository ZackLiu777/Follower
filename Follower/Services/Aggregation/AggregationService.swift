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

    /// 由 Snapshot 计算 Metric：按日/周/月生成聚合指标
    private func buildMetrics(accountId: Int64, snapshots: [Snapshot]) -> [Metric] {
        let calendar = Calendar.current
        var metrics: [Metric] = []

        // Day metrics：每个 Snapshot 映射为一条日 Metric
        for snapshot in snapshots {
            metrics.append(contentsOf: [
                Metric(
                    accountId: accountId,
                    metricType: .followerGrowth,
                    value: Double(snapshot.followersCount),
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
                Metric(
                    accountId: accountId,
                    metricType: .engagementTrend,
                    value: snapshot.engagementRate,
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
                Metric(
                    accountId: accountId,
                    metricType: .averageLikes,
                    value: Double(snapshot.totalLikes),
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
                Metric(
                    accountId: accountId,
                    metricType: .averageComments,
                    value: Double(snapshot.totalComments),
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
                Metric(
                    accountId: accountId,
                    metricType: .averageShares,
                    value: Double(snapshot.totalShares),
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
                Metric(
                    accountId: accountId,
                    metricType: .profileViews,
                    value: Double(snapshot.totalViews),
                    window: .day,
                    observedAt: snapshot.observedAt,
                    createdAt: Date()
                ),
            ])
        }

        // Week metrics：按周聚合（全部 6 种 metricType）
        var weekly: [Date: (fSum: Double, eSum: Double, lSum: Double, cSum: Double, sSum: Double, vSum: Double, count: Int)] = [:]
        for snapshot in snapshots {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: snapshot.observedAt)?.start else { continue }
            let cur = weekly[weekStart] ?? (0, 0, 0, 0, 0, 0, 0)
            weekly[weekStart] = (
                cur.fSum + Double(snapshot.followersCount),
                cur.eSum + snapshot.engagementRate,
                cur.lSum + Double(snapshot.totalLikes),
                cur.cSum + Double(snapshot.totalComments),
                cur.sSum + Double(snapshot.totalShares),
                cur.vSum + Double(snapshot.totalViews),
                cur.count + 1
            )
        }
        for (weekStart, v) in weekly where v.count > 0 {
            let cnt = Double(v.count)
            metrics.append(contentsOf: [
                Metric(accountId: accountId, metricType: .followerGrowth, value: v.fSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .engagementTrend, value: v.eSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageLikes, value: v.lSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageComments, value: v.cSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageShares, value: v.sSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .profileViews, value: v.vSum / cnt, window: .week, observedAt: weekStart, createdAt: Date()),
            ])
        }

        // Month metrics：按月聚合（全部 6 种 metricType）
        var monthly: [Date: (fSum: Double, eSum: Double, lSum: Double, cSum: Double, sSum: Double, vSum: Double, count: Int)] = [:]
        for snapshot in snapshots {
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: snapshot.observedAt)) ?? snapshot.observedAt
            let cur = monthly[monthStart] ?? (0, 0, 0, 0, 0, 0, 0)
            monthly[monthStart] = (
                cur.fSum + Double(snapshot.followersCount),
                cur.eSum + snapshot.engagementRate,
                cur.lSum + Double(snapshot.totalLikes),
                cur.cSum + Double(snapshot.totalComments),
                cur.sSum + Double(snapshot.totalShares),
                cur.vSum + Double(snapshot.totalViews),
                cur.count + 1
            )
        }
        for (monthStart, v) in monthly where v.count > 0 {
            let cnt = Double(v.count)
            metrics.append(contentsOf: [
                Metric(accountId: accountId, metricType: .followerGrowth, value: v.fSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .engagementTrend, value: v.eSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageLikes, value: v.lSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageComments, value: v.cSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageShares, value: v.sSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .profileViews, value: v.vSum / cnt, window: .month, observedAt: monthStart, createdAt: Date()),
            ])
        }

        // Year metrics：按年聚合（全部 6 种 metricType）
        var yearly: [Date: (fSum: Double, eSum: Double, lSum: Double, cSum: Double, sSum: Double, vSum: Double, count: Int)] = [:]
        for snapshot in snapshots {
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: snapshot.observedAt)) ?? snapshot.observedAt
            let cur = yearly[yearStart] ?? (0, 0, 0, 0, 0, 0, 0)
            yearly[yearStart] = (
                cur.fSum + Double(snapshot.followersCount),
                cur.eSum + snapshot.engagementRate,
                cur.lSum + Double(snapshot.totalLikes),
                cur.cSum + Double(snapshot.totalComments),
                cur.sSum + Double(snapshot.totalShares),
                cur.vSum + Double(snapshot.totalViews),
                cur.count + 1
            )
        }
        for (yearStart, v) in yearly where v.count > 0 {
            let cnt = Double(v.count)
            metrics.append(contentsOf: [
                Metric(accountId: accountId, metricType: .followerGrowth, value: v.fSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .engagementTrend, value: v.eSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageLikes, value: v.lSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageComments, value: v.cSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .averageShares, value: v.sSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
                Metric(accountId: accountId, metricType: .profileViews, value: v.vSum / cnt, window: .year, observedAt: yearStart, createdAt: Date()),
            ])
        }

        return metrics
    }
}
