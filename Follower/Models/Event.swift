//
//  Event.swift
//  Follower
//
//  表示一次原始观测/同步记录。append-only，不可就地修改。

import Foundation
import GRDB

// MARK: - EventType

/// 事件类型：快照 / 帖子互动 / 故事浏览 / 粉丝变化 / 互动更新
enum EventType: String, Codable, DatabaseValueConvertible {
    case profileSnapshot
    case postInteraction
    case storyView
    case followerChange
    case engagementUpdate
}

// MARK: - EventSource

/// 事件来源：API 拉取 / 手动录入 / 导入
enum EventSource: String, Codable, DatabaseValueConvertible {
    case api
    case manual
    case `import`
}

// MARK: - Event

/// 原始观测事件，append-only，不可就地修改语义
struct Event: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var accountId: Int64
    var eventType: EventType
    var payload: Data
    var source: EventSource
    var observedAt: Date
    var createdAt: Date

    static let databaseTableName = "event"

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Event {
    /// GRDB 列名映射
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let accountId = Column(CodingKeys.accountId)
        static let eventType = Column(CodingKeys.eventType)
        static let payload = Column(CodingKeys.payload)
        static let source = Column(CodingKeys.source)
        static let observedAt = Column(CodingKeys.observedAt)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Event> {
    /// 按账号 ID 过滤
    func filter(accountId: Int64) -> Self {
        filter(Event.Columns.accountId == accountId)
    }

    /// 按事件类型过滤
    func filter(eventType: EventType) -> Self {
        filter(Event.Columns.eventType == eventType)
    }

    /// 按观测时间区间过滤 → start...end inclusive
    func filter(observedBetween start: Date, and end: Date) -> Self {
        filter(Event.Columns.observedAt >= start && Event.Columns.observedAt <= end)
    }
}
