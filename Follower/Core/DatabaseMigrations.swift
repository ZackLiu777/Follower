//
//  DatabaseMigrations.swift
//  Follower
//
//  数据库迁移 — 全部 schema 演进集中于此文件（替代早期按版本号拆散的 MigrationV1…V7.swift）。
//  每个迁移是一个语义化命名的 enum，暴露 `run(in:)` 纯数据库操作；顺序由 Migrations.registerAll 编排。
//
//  ⚠️ 安全约束：registerMigration 的标识符字符串（"v1_initial_schema" 等）与早期版本一一对应，
//  禁止修改 — 已迁移用户库的 grdb_migrations 表按标识符去重，改名会导致迁移重复执行
//  （V1 建表非幂等 → 重复执行报错，数据库无法打开）。

import Foundation
import GRDB

// MARK: - Migrations

/// 迁移注册中心 — 按版本顺序注册全部迁移（DatabaseManager 的唯一入口）
enum Migrations {
    /// 注册全部迁移。标识符字符串为历史固化值，不得修改（见文件头说明）。
    static func registerAll(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial_schema") { db in
            try V1InitialSchema.run(in: db)
        }
        migrator.registerMigration("v2_draft_post") { db in
            try V2DraftPost.run(in: db)
        }
        migrator.registerMigration("v3_test_account") { db in
            try V3TestAccountFlag.run(in: db)
        }
        migrator.registerMigration("v4_media_post") { db in
            try V4MediaPost.run(in: db)
        }
        migrator.registerMigration("v5_metric_dedup_index") { db in
            try V5MetricDedupIndex.run(in: db)
        }
        migrator.registerMigration("v7_metric_integer_values") { db in
            try V7MetricIntegerValues.run(in: db)
        }
    }
}

// MARK: - v1 初始 schema

/// v1 数据库迁移 — 创建所有表、索引和默认 Premium Feature 记录
enum V1InitialSchema {
    /// 执行 v1 迁移：建表 + 索引 + 默认 Premium 记录
    nonisolated static func run(in db: Database) throws {

        // MARK: account
        try db.create(table: "account") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("platform", .text).notNull()
            t.column("username", .text).notNull()
            t.column("displayName", .text).notNull()
            t.column("authState", .text).notNull()
                .defaults(to: AuthState.authorized.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }

        // 唯一索引：同一平台下 username 唯一
        try db.create(
            index: "idx_account_platform_username",
            on: "account",
            columns: ["platform", "username"],
            unique: true
        )

        // MARK: event
        try db.create(table: "event") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("accountId", .integer).notNull()
                .references("account", onDelete: .cascade)
            t.column("eventType", .text).notNull()
            t.column("payload", .blob).notNull()
            t.column("source", .text).notNull()
            t.column("observedAt", .datetime).notNull()
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(
            index: "idx_event_account_observed",
            on: "event",
            columns: ["accountId", "observedAt"]
        )

        try db.create(
            index: "idx_event_eventType",
            on: "event",
            columns: ["eventType"]
        )

        // MARK: snapshot
        try db.create(table: "snapshot") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("accountId", .integer).notNull()
                .references("account", onDelete: .cascade)
            t.column("followersCount", .integer).notNull().defaults(to: 0)
            t.column("followingCount", .integer).notNull().defaults(to: 0)
            t.column("mediaCount", .integer).notNull().defaults(to: 0)
            t.column("engagementRate", .double).notNull().defaults(to: 0)
            t.column("totalLikes", .integer).notNull().defaults(to: 0)
            t.column("totalComments", .integer).notNull().defaults(to: 0)
            t.column("totalShares", .integer).notNull().defaults(to: 0)
            t.column("totalViews", .integer).notNull().defaults(to: 0)
            t.column("observedAt", .datetime).notNull()
            t.column("createdAt", .datetime).notNull()
        }

        // 一个 account 一天只保留一条 snapshot（upsert 约束）
        try db.create(
            index: "idx_snapshot_account_observed",
            on: "snapshot",
            columns: ["accountId", "observedAt"],
            unique: true
        )

        // MARK: metric
        try db.create(table: "metric") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("accountId", .integer).notNull()
                .references("account", onDelete: .cascade)
            t.column("metricType", .text).notNull()
            t.column("value", .double).notNull()
            t.column("window", .text).notNull()
            t.column("observedAt", .datetime).notNull()
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(
            index: "idx_metric_account_type_window",
            on: "metric",
            columns: ["accountId", "metricType", "window", "observedAt"],
            unique: true
        )

        // MARK: premiumFeature
        try db.create(table: "premiumFeature") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("key", .text).notNull().unique()
            t.column("enabled", .boolean).notNull().defaults(to: false)
            t.column("expiresAt", .datetime)
            t.column("createdAt", .datetime).notNull()
        }

        // 插入默认 Premium Feature 记录
        for key in PremiumFeatureKey.allCases {
            try db.execute(
                sql: "INSERT INTO premiumFeature (key, enabled, createdAt) VALUES (?, 0, ?)",
                arguments: [key.rawValue, Date()]
            )
        }
    }
}

// MARK: - v2 发布助手

/// v2 数据库迁移 — 发布助手数据层
enum V2DraftPost {
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

// MARK: - v3 测试账号标记

/// v3 数据库迁移 — 测试账号标记
enum V3TestAccountFlag {
    /// 执行 v3 迁移：account 增加 isTest 列（幂等：已存在则跳过）
    nonisolated static func run(in db: Database) throws {

        // MARK: account — 增加 isTest 列（幂等：已存在则跳过）
        let accountColumns = try db.columns(in: "account")
        if !accountColumns.contains(where: { $0.name == "isTest" }) {
            try db.alter(table: "account") { t in
                t.add(column: "isTest", .boolean).notNull().defaults(to: false)
            }
        }
    }
}

// MARK: - v4 最近帖子持久化

/// v4 数据库迁移 — 最近帖子持久化
///
/// 背景：MediaPost 原仅存于 SyncEngine 内存缓存（mediaCache），App 重启后丢失
/// → Dashboard 最近内容消失。v4 将帖子持久化到 SQLite（幂等：IF NOT EXISTS）。
enum V4MediaPost {
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

// MARK: - v5 metric 去重 + 唯一索引补齐

/// v5 数据库迁移 — metric 去重 + 唯一索引补齐（幂等：可安全重复执行）
///
/// 背景：upsertBatch 的替换语义依赖唯一索引。若历史库索引缺失，
/// INSERT OR REPLACE 退化为普通 INSERT，每次 sync 追加重复行
/// → 趋势图表「刷新后重复添加数据」。v5 一次性修复：去重 + 建索引双保险。
enum V5MetricDedupIndex {
    /// 执行 v5 迁移：去重 + 建索引（均幂等）
    nonisolated static func run(in db: Database) throws {

        // MARK: metric — 同键重复行清理（每组保留最早一行，其余删除）
        // 唯一索引存在时本步自然无操作；缺失时清理历史追加产生的重复行
        try db.execute(sql: """
            DELETE FROM metric
            WHERE id NOT IN (
                SELECT MIN(id) FROM metric
                GROUP BY accountId, metricType, window, observedAt
            )
            """)

        // MARK: metric — 唯一索引补齐（幂等：已存在则跳过）
        let indexNames = try db.indexes(on: "metric").map(\.name)
        if !indexNames.contains("idx_metric_account_type_window") {
            try db.create(
                index: "idx_metric_account_type_window",
                on: "metric",
                columns: ["accountId", "metricType", "window", "observedAt"],
                unique: true
            )
        }
    }
}

// MARK: - v7 Metric 数值整数化

/// v7 迁移：Metric 数值整数化。
/// 旧版本 Metric.value 为 Double：
///   - engagementTrend 存 0~1 比率（如 0.0543）
///   - 计数类指标存浮点（历史平均产生的 8250.5 等）
/// 新版本统一整数语义：
///   - engagementTrend → 万分比整数（0.0543 → 543）
///   - 计数类 → ROUND 四舍五入取整
enum V7MetricIntegerValues {
    /// 执行 v7 迁移：换算历史 Metric 数值为整数语义
    /// - 幂等：迁移只注册运行一次；两个 UPDATE 均为确定性换算
    nonisolated static func run(in db: Database) throws {
        // 1. engagementTrend：旧比率（0 < value < 1）→ 万分比整数
        //    条件排除已是万分比的旧值（> 1），防止重复换算
        try db.execute(sql: """
            UPDATE metric
            SET value = CAST(ROUND(value * 10000) AS INTEGER)
            WHERE metricType = 'engagementTrend' AND value > 0 AND value < 1
            """)

        // 2. 其余计数类：ROUND 取整（8250.5 → 8251）
        try db.execute(sql: """
            UPDATE metric
            SET value = CAST(ROUND(value) AS INTEGER)
            WHERE metricType != 'engagementTrend'
            """)
    }
}
