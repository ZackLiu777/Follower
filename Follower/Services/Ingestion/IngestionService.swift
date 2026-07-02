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
        let profilePayload = try? JSONEncoder().encode(profile)
        if let payload = profilePayload {
            events.append(Event(
                accountId: accountId,
                eventType: .profileSnapshot,
                payload: payload,
                source: .api,
                observedAt: profile.fetchedAt,
                createdAt: Date()
            ))
        } else {
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
