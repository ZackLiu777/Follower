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

struct AggregationResult {
    let snapshotsUpdated: Int
    let metricsUpdated: Int
}

// MARK: - AggregationServiceProtocol

protocol AggregationServiceProtocol: Sendable {
    /// 对指定时间范围的 Event 执行聚合，生成 Snapshot 和 Metric
    func aggregate(accountId: Int64, from: Date, to: Date) async throws -> AggregationResult
    /// 重新计算所有 Snapshot（全量重建）
    func rebuildAll(accountId: Int64) async throws -> AggregationResult
}

// MARK: - AggregationService

final class AggregationService: AggregationServiceProtocol {
    private let eventRepo: EventRepositoryProtocol
    private let snapshotRepo: SnapshotRepositoryProtocol
    private let metricRepo: MetricRepositoryProtocol

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

    func rebuildAll(accountId: Int64) async throws -> AggregationResult {
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
        var grouped: [Date: (followers: Int, following: Int, media: Int, likes: Int, comments: Int, shares: Int, views: Int, engagementRate: Double, count: Int)] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.observedAt)

            switch event.eventType {
            case .profileSnapshot:
                if let profile = try? JSONDecoder().decode(APIProfileResponse.self, from: event.payload) {
                    let current = grouped[day] ?? (0, 0, 0, 0, 0, 0, 0, 0, 0)
                    grouped[day] = (
                        profile.followersCount,
                        profile.followingCount,
                        profile.mediaCount,
                        profile.totalLikes,
                        profile.totalComments,
                        profile.totalShares,
                        profile.totalViews,
                        profile.engagementRate,
                        current.count + 1
                    )
                }
            case .followerChange:
                if let point = try? JSONDecoder().decode(APITrendDataPoint.self, from: event.payload) {
                    let current = grouped[day] ?? (0, 0, 0, 0, 0, 0, 0, 0, 0)
                    grouped[day] = (
                        point.followersCount,
                        point.followingCount,
                        point.mediaCount,
                        current.likes,
                        current.comments,
                        current.shares,
                        current.views,
                        point.engagementRate,
                        current.count + 1
                    )
                }
            default:
                break
            }
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

        // Week metrics：按周聚合
        var weekly: [Date: (followersSum: Double, engagementSum: Double, count: Int)] = [:]
        for snapshot in snapshots {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: snapshot.observedAt)?.start else {
                continue
            }
            let current = weekly[weekStart] ?? (0, 0, 0)
            weekly[weekStart] = (
                current.followersSum + Double(snapshot.followersCount),
                current.engagementSum + snapshot.engagementRate,
                current.count + 1
            )
        }
        for (weekStart, values) in weekly where values.count > 0 {
            metrics.append(Metric(
                accountId: accountId,
                metricType: .followerGrowth,
                value: values.followersSum / Double(values.count),
                window: .week,
                observedAt: weekStart,
                createdAt: Date()
            ))
            metrics.append(Metric(
                accountId: accountId,
                metricType: .engagementTrend,
                value: values.engagementSum / Double(values.count),
                window: .week,
                observedAt: weekStart,
                createdAt: Date()
            ))
        }

        // Month metrics：按月聚合
        var monthly: [Date: (followersSum: Double, engagementSum: Double, count: Int)] = [:]
        for snapshot in snapshots {
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: snapshot.observedAt)) ?? snapshot.observedAt
            let current = monthly[monthStart] ?? (0, 0, 0)
            monthly[monthStart] = (
                current.followersSum + Double(snapshot.followersCount),
                current.engagementSum + snapshot.engagementRate,
                current.count + 1
            )
        }
        for (monthStart, values) in monthly where values.count > 0 {
            metrics.append(Metric(
                accountId: accountId,
                metricType: .followerGrowth,
                value: values.followersSum / Double(values.count),
                window: .month,
                observedAt: monthStart,
                createdAt: Date()
            ))
            metrics.append(Metric(
                accountId: accountId,
                metricType: .engagementTrend,
                value: values.engagementSum / Double(values.count),
                window: .month,
                observedAt: monthStart,
                createdAt: Date()
            ))
        }

        return metrics
    }
}
