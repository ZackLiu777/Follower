//
//  EventRepository.swift
//  Follower
//
//  Event 数据访问层。
//  Event 是 append-only 的原始记录。只允许追加和查询，不允许修改或删除。
//

import Foundation
import GRDB

// MARK: - EventRepositoryProtocol

/// Event 数据访问协议，仅支持追加和查询，不允许修改或删除原始 Event
protocol EventRepositoryProtocol: Sendable {
    /// 获取指定账号的全部 Event（按 observedAt 降序）
    func fetchAll(accountId: Int64) async throws -> [Event]
    /// 按事件类型查询，支持 limit 分页
    func fetch(accountId: Int64, eventType: EventType, limit: Int) async throws -> [Event]
    /// 按时间区间查询 Event
    func fetch(accountId: Int64, from: Date, to: Date) async throws -> [Event]
    /// 追加单条 Event
    func insert(_ event: Event) async throws -> Event
    /// 批量追加 Event，在同一个事务内执行
    func insertBatch(_ events: [Event]) async throws -> [Event]
    /// 统计指定账号的 Event 总数
    func count(accountId: Int64) async throws -> Int
    /// 获取最近一条 Event 的观测时间，用于增量同步判断
    func latestObservedAt(accountId: Int64) async throws -> Date?
}

// MARK: - EventRepository

/// EventRepository 实现，基于 GRDB 提供 append-only Event 持久化
final class EventRepository: EventRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 查询指定账号全部 Event，按 observedAt 降序排列
    func fetchAll(accountId: Int64) async throws -> [Event] {
        try await db.read { db in
            try Event
                .filter(Event.Columns.accountId == accountId)
                .order(Event.Columns.observedAt.desc)
                .fetchAll(db)
        }
    }

    /// 按类型查询，支持分页（limit）
    func fetch(accountId: Int64, eventType: EventType, limit: Int = 500) async throws -> [Event] {
        try await db.read { db in
            try Event
                .filter(Event.Columns.accountId == accountId)
                .filter(Event.Columns.eventType == eventType)
                .order(Event.Columns.observedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// 按时间范围查询
    func fetch(accountId: Int64, from: Date, to: Date) async throws -> [Event] {
        try await db.read { db in
            try Event
                .filter(Event.Columns.accountId == accountId)
                .filter(Event.Columns.observedAt >= from && Event.Columns.observedAt <= to)
                .order(Event.Columns.observedAt.asc)
                .fetchAll(db)
        }
    }

    /// 追加单条 Event，自动填充 createdAt
    func insert(_ event: Event) async throws -> Event {
        try await db.write { db in
            var record = event
            record.createdAt = Date()
            try record.insert(db)
            return record
        }
    }

    /// 批量追加
    func insertBatch(_ events: [Event]) async throws -> [Event] {
        try await db.batchWrite { db in
            var results: [Event] = []
            for var event in events {
                event.createdAt = Date()
                try event.insert(db)
                results.append(event)
            }
            return results
        }
    }

    /// 按账号统计 Event 数量
    func count(accountId: Int64) async throws -> Int {
        try await db.read { db in
            try Event
                .filter(Event.Columns.accountId == accountId)
                .fetchCount(db)
        }
    }

    /// 最近一条 Event 的观测时间，用于增量同步
    func latestObservedAt(accountId: Int64) async throws -> Date? {
        try await db.read { db in
            try Event
                .filter(Event.Columns.accountId == accountId)
                .order(Event.Columns.observedAt.desc)
                .limit(1)
                .fetchOne(db)?
                .observedAt
        }
    }
}
