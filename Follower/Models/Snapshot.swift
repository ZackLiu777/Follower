//
//  Snapshot.swift
//  Follower
//
//  表示某一时间点的账号状态快照。面向 UI 查询，支持 upsert。

import Foundation
import GRDB

// MARK: - Snapshot

/// 账号状态快照，面向 UI 查询，支持 upsert 覆盖更新
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

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Snapshot {
    /// GRDB 列名映射
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
    /// 按账号 ID 过滤
    func filter(accountId: Int64) -> Self {
        filter(Snapshot.Columns.accountId == accountId)
    }
    /// 按观测时间区间过滤 → start...end inclusive
    func filter(observedBetween start: Date, and end: Date) -> Self {
        filter(Snapshot.Columns.observedAt >= start && Snapshot.Columns.observedAt <= end)
    }
    /// 按观测时间排序，默认降序（最新在前）
    func orderedByObservedAt(ascending: Bool = false) -> Self {
        ascending
            ? order(Snapshot.Columns.observedAt.asc)
            : order(Snapshot.Columns.observedAt.desc)
    }
}
