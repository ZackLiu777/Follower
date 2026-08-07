//
//  MigrationV2.swift
//  Follower
//
//  v2 数据库迁移：
//  - account 增加 accountType 列（评论管理需判断 BUSINESS/CREATOR）
//  - 新增 draftPost 表（发布助手草稿）
//

import Foundation
import GRDB

// MARK: - MigrationV2

/// v2 数据库迁移 — 发布助手数据层
enum MigrationV2 {
    /// 执行 v2 迁移：account 加列 + 创建 draftPost 表
    nonisolated static func run(in db: Database) throws {

        // MARK: account — 增加 accountType 列（幂等：已存在则跳过）
        let accountColumns = try db.columns(in: "account")
        if !accountColumns.contains(where: { $0.name == "accountType" }) {
            try db.alter(table: "account") { t in
                t.add(column: "accountType", .text)
            }
        }

        // MARK: draftPost
        try db.create(table: "draftPost") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("accountId", .integer)
                .references("account", onDelete: .cascade)
            t.column("caption", .text).notNull()
            t.column("imageFilename", .text)
            t.column("scheduledAt", .datetime)
            t.column("status", .text).notNull()
                .defaults(to: DraftPostStatus.draft.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }

        // 按状态过滤的索引（队列页按状态分组展示）
        try db.create(
            index: "idx_draftPost_status",
            on: "draftPost",
            columns: ["status"]
        )
    }
}
