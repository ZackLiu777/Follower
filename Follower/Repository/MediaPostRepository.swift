//
//  MediaPostRepository.swift
//  Follower
//
//  MediaPost（最近帖子）数据访问层。
//  v4 起帖子持久化到 media_post 表 — 解决 App 重启后 Dashboard 帖子丢失。
//

import Foundation
import GRDB

// MARK: - MediaPostRepositoryProtocol

/// MediaPost 数据访问协议 — 帖子的批量落库与最近查询
protocol MediaPostRepositoryProtocol: Sendable {
    /// 批量 upsert 帖子（同 igMediaID 替换，依赖唯一键），返回持久化后的帖子
    func upsertBatch(accountId: Int64, media: [MediaPost]) async throws -> [MediaPost]
    /// 查询最近帖子（按日期降序，limit 限制条数）
    func fetchRecent(accountId: Int64, limit: Int) async throws -> [MediaPost]
}

// MARK: - MediaPostRepository

/// MediaPostRepository 实现，基于 GRDB 提供帖子持久化
final class MediaPostRepository: MediaPostRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 批量 upsert：同事务内逐条 INSERT OR REPLACE。
    /// 依赖 media_post 表 igMediaID 唯一索引（同账号下 IG 媒体 id 全局唯一），
    /// 重复 sync 同一篇帖子时替换而非追加。
    func upsertBatch(accountId: Int64, media: [MediaPost]) async throws -> [MediaPost] {
        try await db.batchWrite { db in
            let sql = """
                INSERT OR REPLACE INTO media_post
                (id, accountId, igMediaID, type, date, likes, comments, caption, mediaURL, permalink)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            for post in media {
                try db.execute(
                    sql: sql,
                    arguments: [
                        post.id, post.accountId, post.igMediaID, post.type.rawValue,
                        post.date, post.likes, post.comments, post.caption,
                        post.mediaURL, post.permalink,
                    ]
                )
            }
            return media
        }
    }

    /// 查询最近帖子（Dashboard 最近内容 / 帖子列表页数据源）
    func fetchRecent(accountId: Int64, limit: Int) async throws -> [MediaPost] {
        try await db.read { db in
            try MediaPost
                .filter(MediaPost.Columns.accountId == accountId)
                .order(MediaPost.Columns.date.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
