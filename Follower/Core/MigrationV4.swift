//
//  MigrationV4.swift
//  Follower
//
//  v4 数据库迁移：
//  - media_post 表（最近帖子持久化）
//
//  背景：MediaPost 原仅存于 SyncEngine 内存缓存（mediaCache），App 重启后丢失
//  → Dashboard 最近内容消失。v4 将帖子持久化到 SQLite（幂等：IF NOT EXISTS）。
//

import Foundation
import GRDB

// MARK: - MigrationV4

/// v4 数据库迁移 — 最近帖子持久化
enum MigrationV4 {
    /// 执行 v4 迁移：创建 media_post 表（幂等：已存在则跳过）
    nonisolated static func run(in db: Database) throws {
        try db.create(table: "media_post", ifNotExists: true) { t in
            // 主键为 SyncEngine 派生的业务 id（igMediaID 的稳定映射），非自增
            t.primaryKey("id", .integer)
            // 账号外键：删除账号时级联清理帖子
            t.column("accountId", .integer).notNull()
                .references("account", onDelete: .cascade)
            // 业务唯一键：同一篇帖子（同账号下 igMediaID 全局唯一）重复 sync 时替换而非追加
            t.column("igMediaID", .text).notNull().unique()
            t.column("type", .text).notNull()
            t.column("date", .datetime).notNull()
            t.column("likes", .integer).notNull()
            t.column("comments", .integer).notNull()
            t.column("caption", .text).notNull()
            t.column("mediaURL", .text)
            t.column("permalink", .text)
        }
    }
}
