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

protocol EventRepositoryProtocol: Sendable {
    func fetchAll(accountId: Int64) async throws -> [Event]
    func fetch(accountId: Int64, eventType: EventType, limit: Int) async throws -> [Event]
    func fetch(accountId: Int64, from: Date, to: Date) async throws -> [Event]
    func insert(_ event: Event) async throws -> Event
    func insertBatch(_ events: [Event]) async throws -> [Event]
    func count(accountId: Int64) async throws -> Int
    func latestObservedAt(accountId: Int64) async throws -> Date?
}

// MARK: - EventRepository

final class EventRepository: EventRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

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
