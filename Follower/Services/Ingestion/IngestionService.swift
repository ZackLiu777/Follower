//
//  IngestionService.swift
//  Follower
//
//  数据摄取服务，负责：
//  - 接收 API 返回的数据
//  - 将外部 JSON / DTO 映射为内部模型
//  - 生成 Event 记录
//

import Foundation

// MARK: - IngestionServiceProtocol

/// 数据摄取服务协议：将外部 API 数据转换为内部 Event 并触发聚合
protocol IngestionServiceProtocol: Sendable {
    /// 摄取 Profile + Trend 数据，返回同步结果
    func ingest(
        accountId: Int64,
        profile: APIProfileResponse,
        trend: APITrendResponse
    ) async throws -> SyncResult

    /// 从 JSON 数据直接摄取
    func ingestJSON(accountId: Int64, jsonData: Data) async throws -> SyncResult
}

// MARK: - IngestionService

/// 数据摄取服务实现：DTO → Event 写入 → 触发 Aggregation 管道
final class IngestionService: IngestionServiceProtocol {
    private let eventRepo: EventRepositoryProtocol
    private let aggregationService: AggregationServiceProtocol

    /// 注入 EventRepository 和 AggregationService
    init(
        eventRepo: EventRepositoryProtocol,
        aggregationService: AggregationServiceProtocol
    ) {
        self.eventRepo = eventRepo
        self.aggregationService = aggregationService
    }

    /// 摄取 Profile + Trend 数据：编码为 Event → 批量写入 → 触发聚合
    func ingest(
        accountId: Int64,
        profile: APIProfileResponse,
        trend: APITrendResponse
    ) async throws -> SyncResult {
        var events: [Event] = []
        var errors: [Error] = []

        // 1. Profile Snapshot → Event
        // v0.08：业务字段与最近一次观测完全一致 → 跳过写入（数据未变化的同步
        // 不产生重复观测，图表不再出现「相同数据、时间不同」的重复点）。
        // 已有事件一律不动；任何一项业务字段变化都会照常写入新观测。
        let unchanged = await isUnchanged(accountId: accountId, profile: profile)
        let profilePayload = unchanged ? nil : try? JSONEncoder().encode(profile)
        if let payload = profilePayload {
            events.append(Event(
                accountId: accountId,
                eventType: .profileSnapshot,
                payload: payload,
                source: .api,
                observedAt: profile.fetchedAt,
                createdAt: Date()
            ))
        } else if !unchanged {
            errors.append(IngestionError.encodingFailure("profile"))
        }

        // 2. Trend Data Points → Events
        for point in trend.dataPoints {
            let pointPayload = try? JSONEncoder().encode(point)
            if let payload = pointPayload {
                events.append(Event(
                    accountId: accountId,
                    eventType: .followerChange,
                    payload: payload,
                    source: .api,
                    observedAt: point.date,
                    createdAt: Date()
                ))
            }
        }

        // 3. 批量写入 Event
        var eventsCreated = 0
        if !events.isEmpty {
            _ = try await eventRepo.insertBatch(events)
            eventsCreated = events.count
        }

        // 4. 触发聚合：Event → Snapshot → Metric
        let aggregationResult = try await aggregationService.aggregate(
            accountId: accountId,
            from: events.map(\.observedAt).min() ?? Date(),
            to: Date()
        )

        return SyncResult(
            accountId: accountId,
            eventsCreated: eventsCreated,
            snapshotsUpdated: aggregationResult.snapshotsUpdated,
            metricsUpdated: aggregationResult.metricsUpdated,
            errors: errors
        )
    }

    // MARK: - 重复观测抑制（v0.08）

    /// 判断本次 profile 观测的业务字段与最近一次 profileSnapshot 是否完全一致。
    /// - Returns: true = 数据未变化，应跳过写入（避免重复观测）；
    ///   false = 存在变化，正常写入新观测。
    /// - Note: 只比较业务字段，排除 fetchedAt（每次同步必然不同的时间元数据）。
    private func isUnchanged(accountId: Int64, profile: APIProfileResponse) async -> Bool {
        guard let last = try? await eventRepo.fetch(
            accountId: accountId, eventType: .profileSnapshot, limit: 1
        ).first,
        let lastProfile = try? JSONDecoder().decode(APIProfileResponse.self, from: last.payload)
        else { return false }
        return Self.isSameProfile(lastProfile, profile)
    }

    /// 业务字段全等比较（排除 fetchedAt 时间元数据）
    static func isSameProfile(_ a: APIProfileResponse, _ b: APIProfileResponse) -> Bool {
        a.username == b.username
            && a.displayName == b.displayName
            && a.followersCount == b.followersCount
            && a.followingCount == b.followingCount
            && a.mediaCount == b.mediaCount
            && a.totalLikes == b.totalLikes
            && a.totalComments == b.totalComments
            && a.totalShares == b.totalShares
            && a.totalViews == b.totalViews
            && a.engagementRate == b.engagementRate
    }

    /// 从 JSON 导入（用户导出再导入的场景）
    func ingestJSON(accountId: Int64, jsonData: Data) async throws -> SyncResult {
        let decoder = JSONDecoder()
        var events: [Event] = []

        // 尝试解析为 Event 数组
        if let eventArray = try? decoder.decode([Event].self, from: jsonData) {
            events = eventArray
        }

        var eventsCreated = 0
        if !events.isEmpty {
            _ = try await eventRepo.insertBatch(events)
            eventsCreated = events.count
        }

        let aggregationResult = try await aggregationService.aggregate(
            accountId: accountId,
            from: events.map(\.observedAt).min() ?? Date(),
            to: Date()
        )

        return SyncResult(
            accountId: accountId,
            eventsCreated: eventsCreated,
            snapshotsUpdated: aggregationResult.snapshotsUpdated,
            metricsUpdated: aggregationResult.metricsUpdated,
            errors: []
        )
    }
}

// MARK: - Ingestion Errors

/// 数据摄取错误类型
enum IngestionError: Error {
    case encodingFailure(String)
    case invalidData(String)
}
