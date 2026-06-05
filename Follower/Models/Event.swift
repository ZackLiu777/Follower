//
//  Event.swift
//  Follower
//
//  表示一次原始观测/同步记录。append-only，不可就地修改。

import Foundation
import GRDB

// MARK: - EventType

enum EventType: String, Codable, DatabaseValueConvertible {
    case profileSnapshot
    case postInteraction
    case storyView
    case followerChange
    case engagementUpdate
}

// MARK: - EventSource

enum EventSource: String, Codable, DatabaseValueConvertible {
    case api
    case manual
    case `import`
}

// MARK: - Event

struct Event: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var accountId: Int64
    var eventType: EventType
    var payload: Data
    var source: EventSource
    var observedAt: Date
    var createdAt: Date

    static let databaseTableName = "event"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Event {
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
    func filter(accountId: Int64) -> Self {
        filter(Event.Columns.accountId == accountId)
    }

    func filter(eventType: EventType) -> Self {
        filter(Event.Columns.eventType == eventType)
    }

    func filter(observedBetween start: Date, and end: Date) -> Self {
        filter(Event.Columns.observedAt >= start && Event.Columns.observedAt <= end)
    }
}
