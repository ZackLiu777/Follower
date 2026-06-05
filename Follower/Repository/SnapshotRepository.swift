//
//  SnapshotRepository.swift
//  Follower
//
//  Snapshot 数据访问层。
//  Snapshot 面向 UI 查询，支持 upsert。控制查询成本。
//

import Foundation
import GRDB

// MARK: - SnapshotRepositoryProtocol

protocol SnapshotRepositoryProtocol: Sendable {
    func latest(accountId: Int64) async throws -> Snapshot?
    func fetch(accountId: Int64, from: Date, to: Date) async throws -> [Snapshot]
    func fetchAll(accountId: Int64) async throws -> [Snapshot]
    func upsert(_ snapshot: Snapshot) async throws -> Snapshot
    func upsertBatch(_ snapshots: [Snapshot]) async throws -> [Snapshot]
}

// MARK: - SnapshotRepository

final class SnapshotRepository: SnapshotRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 获取最新一条 Snapshot（用于 Dashboard 卡片展示）
    func latest(accountId: Int64) async throws -> Snapshot? {
        try await db.read { db in
            try Snapshot
                .filter(Snapshot.Columns.accountId == accountId)
                .order(Snapshot.Columns.observedAt.desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    /// 按时间范围查询（用于趋势图表）
    func fetch(accountId: Int64, from: Date, to: Date) async throws -> [Snapshot] {
        try await db.read { db in
            try Snapshot
                .filter(Snapshot.Columns.accountId == accountId)
                .filter(Snapshot.Columns.observedAt >= from && Snapshot.Columns.observedAt <= to)
                .order(Snapshot.Columns.observedAt.asc)
                .fetchAll(db)
        }
    }

    func fetchAll(accountId: Int64) async throws -> [Snapshot] {
        try await db.read { db in
            try Snapshot
                .filter(Snapshot.Columns.accountId == accountId)
                .order(Snapshot.Columns.observedAt.desc)
                .fetchAll(db)
        }
    }

    /// Upsert 单条 Snapshot（同 account + 同 observedAt 则覆盖）
    /// 使用 (accountId, observedAt) 作为冲突检测列，
    /// 因为表上 id 是 auto-increment，不能依赖主键冲突检测。
    func upsert(_ snapshot: Snapshot) async throws -> Snapshot {
        try await db.write { db in
            var record = snapshot
            if let existing = try Snapshot
                .filter(Snapshot.Columns.accountId == record.accountId)
                .filter(Snapshot.Columns.observedAt == record.observedAt)
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

    func upsertBatch(_ snapshots: [Snapshot]) async throws -> [Snapshot] {
        try await db.batchWrite { db in
            var results: [Snapshot] = []
            for var s in snapshots {
                if let existing = try Snapshot
                    .filter(Snapshot.Columns.accountId == s.accountId)
                    .filter(Snapshot.Columns.observedAt == s.observedAt)
                    .fetchOne(db) {
                    s.id = existing.id
                    s.createdAt = Date()
                    try s.update(db)
                } else {
                    s.createdAt = Date()
                    try s.insert(db)
                }
                results.append(s)
            }
            return results
        }
    }
}
