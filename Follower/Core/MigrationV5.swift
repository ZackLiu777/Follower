//
//  MigrationV5.swift
//  Follower
//
//  v5 数据库迁移：
//  - metric 表同键重复行清理（每组保留一行）
//  - 补齐 idx_metric_account_type_window 唯一索引（若缺失）
//
//  背景：upsertBatch 的替换语义依赖唯一索引。若历史库索引缺失，
//  INSERT OR REPLACE 退化为普通 INSERT，每次 sync 追加重复行
//  → 趋势图表「刷新后重复添加数据」。v5 一次性修复：去重 + 建索引双保险。
//

import Foundation
import GRDB

// MARK: - MigrationV5

/// v5 数据库迁移 — metric 去重 + 唯一索引补齐（幂等：可安全重复执行）
enum MigrationV5 {
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
