//
//  Snapshot.swift
//  Follower
//
//  表示某一时间点的账号状态快照。面向 UI 查询，支持 upsert。

import Foundation
import GRDB

// MARK: - Snapshot

struct Snapshot: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var accountId: Int64
    var followersCount: Int
    var followingCount: Int
    var mediaCount: Int
    var engagementRate: Double
    var totalLikes: Int
    var totalComments: Int
    var totalShares: Int
    var totalViews: Int
    var observedAt: Date
    var createdAt: Date

    static let databaseTableName = "snapshot"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Snapshot {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let accountId = Column(CodingKeys.accountId)
        static let followersCount = Column(CodingKeys.followersCount)
        static let followingCount = Column(CodingKeys.followingCount)
        static let mediaCount = Column(CodingKeys.mediaCount)
        static let engagementRate = Column(CodingKeys.engagementRate)
        static let totalLikes = Column(CodingKeys.totalLikes)
        static let totalComments = Column(CodingKeys.totalComments)
        static let totalShares = Column(CodingKeys.totalShares)
        static let totalViews = Column(CodingKeys.totalViews)
        static let observedAt = Column(CodingKeys.observedAt)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Snapshot> {
    func filter(accountId: Int64) -> Self {
        filter(Snapshot.Columns.accountId == accountId)
    }
    func filter(observedBetween start: Date, and end: Date) -> Self {
        filter(Snapshot.Columns.observedAt >= start && Snapshot.Columns.observedAt <= end)
    }
    func orderedByObservedAt(ascending: Bool = false) -> Self {
        ascending
            ? order(Snapshot.Columns.observedAt.asc)
            : order(Snapshot.Columns.observedAt.desc)
    }
}
