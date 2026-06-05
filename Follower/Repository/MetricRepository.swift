//
//  MetricRepository.swift
//  Follower
//
//  Metric 数据访问层。

import Foundation
import GRDB

// MARK: - MetricRepositoryProtocol

protocol MetricRepositoryProtocol: Sendable {
    func fetch(accountId: Int64, metricType: MetricType, window: TimeWindow, limit: Int) async throws -> [Metric]
    func fetch(accountId: Int64, window: TimeWindow, from: Date, to: Date) async throws -> [Metric]
    func upsert(_ metric: Metric) async throws -> Metric
    func upsertBatch(_ metrics: [Metric]) async throws -> [Metric]
    func deleteOldMetrics(accountId: Int64, olderThan: Date) async throws -> Int
}

// MARK: - MetricRepository

final class MetricRepository: MetricRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

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

    func deleteOldMetrics(accountId: Int64, olderThan: Date) async throws -> Int {
        try await db.write { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .filter(Metric.Columns.observedAt < olderThan)
                .deleteAll(db)
        }
    }
}
