//
//  MetricRepository.swift
//  Follower
//
//  Metric 数据访问层。

import Foundation
import GRDB

// MARK: - MetricRepositoryProtocol

/// Metric 数据访问协议，提供聚合指标的查询与 upsert 操作
protocol MetricRepositoryProtocol: Sendable {
    /// 按账号+指标类型+时间窗获取指标列表，支持 limit
    func fetch(accountId: Int64, metricType: MetricType, window: TimeWindow, limit: Int) async throws -> [Metric]
    /// 按账号+时间窗+时间区间查询指标
    func fetch(accountId: Int64, window: TimeWindow, from: Date, to: Date) async throws -> [Metric]
    /// Upsert 单条 Metric（同一复合键存在则更新，否则插入）
    func upsert(_ metric: Metric) async throws -> Metric
    /// 批量 upsert Metric
    func upsertBatch(_ metrics: [Metric]) async throws -> [Metric]
    /// 清理指定账号在某个时间点之前的旧指标数据
    func deleteOldMetrics(accountId: Int64, olderThan: Date) async throws -> Int
}

// MARK: - MetricRepository

/// MetricRepository 实现，基于 GRDB 提供 Metric 的查询与 upsert 持久化
final class MetricRepository: MetricRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 按账号 + 指标类型 + 时间窗查询，limit 控制返回条数
    func fetch(accountId: Int64, metricType: MetricType, window: TimeWindow, limit: Int = 365) async throws -> [Metric] {
        try await db.read { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .filter(Metric.Columns.metricType == metricType)
                .filter(Metric.Columns.window == window)
                .order(Metric.Columns.observedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// 按账号 + 时间窗 + 时间范围查询，结果按时间升序
    func fetch(accountId: Int64, window: TimeWindow, from: Date, to: Date) async throws -> [Metric] {
        try await db.read { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .filter(Metric.Columns.window == window)
                .filter(Metric.Columns.observedAt >= from && Metric.Columns.observedAt <= to)
                .order(Metric.Columns.observedAt.asc)
                .fetchAll(db)
        }
    }

    /// Upsert 单条 Metric：以 (accountId, metricType, window, observedAt) 作为唯一性判断
    func upsert(_ metric: Metric) async throws -> Metric {
        try await db.write { db in
            var record = metric
            if let existing = try Metric
                .filter(Metric.Columns.accountId == record.accountId)
                .filter(Metric.Columns.metricType == record.metricType)
                .filter(Metric.Columns.window == record.window)
                .filter(Metric.Columns.observedAt == record.observedAt)
                .fetchOne(db) {
                record.id = existing.id
                record.createdAt = Date()
                try record.update(db)
            } else {
                record.createdAt = Date()
                try record.insert(db)
            }
            return record
        }
    }

    /// 批量 upsert：遍历并逐条判断存在则更新、不存在则插入
    func upsertBatch(_ metrics: [Metric]) async throws -> [Metric] {
        try await db.batchWrite { db in
            var results: [Metric] = []
            for var m in metrics {
                if let existing = try Metric
                    .filter(Metric.Columns.accountId == m.accountId)
                    .filter(Metric.Columns.metricType == m.metricType)
                    .filter(Metric.Columns.window == m.window)
                    .filter(Metric.Columns.observedAt == m.observedAt)
                    .fetchOne(db) {
                    m.id = existing.id
                    m.createdAt = Date()
                    try m.update(db)
                } else {
                    m.createdAt = Date()
                    try m.insert(db)
                }
                results.append(m)
            }
            return results
        }
    }

    /// 清理旧指标数据，返回被删除的行数（用于数据回收策略）
    func deleteOldMetrics(accountId: Int64, olderThan: Date) async throws -> Int {
        try await db.write { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .filter(Metric.Columns.observedAt < olderThan)
                .deleteAll(db)
        }
    }
}
