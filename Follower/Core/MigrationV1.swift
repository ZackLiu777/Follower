//
//  MigrationV1.swift
//  Follower
//
//  初始数据库 Schema：
//  - account
//  - event
//  - snapshot
//  - metric
//  - premiumFeature
//

import Foundation
import GRDB

// MARK: - MigrationV1

enum MigrationV1 {
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
