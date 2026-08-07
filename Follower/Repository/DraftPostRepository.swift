//
//  DraftPostRepository.swift
//  Follower
//
//  DraftPost 数据访问层。
//  唯一入口：所有发布助手草稿的持久化读写必须经过此 Repository。
//

import Foundation
import GRDB

// MARK: - DraftPostRepositoryProtocol

/// DraftPost 数据访问协议，定义发布助手草稿的统一入口
protocol DraftPostRepositoryProtocol: Sendable {
    /// 获取全部草稿（按更新时间倒序）
    func fetchAll() async throws -> [DraftPost]
    /// 按主键 ID 获取单条草稿
    func fetch(id: Int64) async throws -> DraftPost?
    /// 按状态过滤草稿
    func fetch(status: DraftPostStatus) async throws -> [DraftPost]
    /// 插入新草稿，自动设置 createdAt/updatedAt
    func insert(_ draft: DraftPost) async throws -> DraftPost
    /// 更新草稿，自动刷新 updatedAt
    func update(_ draft: DraftPost) async throws
    /// 按主键删除草稿
    func delete(id: Int64) async throws
    /// 统计草稿总条数
    func count() async throws -> Int
}

// MARK: - DraftPostRepository

/// DraftPostRepository 实现，基于 GRDB 提供所有草稿持久化操作
final class DraftPostRepository: DraftPostRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 查询全部草稿（最新修改在前）
    func fetchAll() async throws -> [DraftPost] {
        try await db.read { db in
            try DraftPost
                .order(DraftPost.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }

    /// 按主键 ID 查询单条草稿
    func fetch(id: Int64) async throws -> DraftPost? {
        try await db.read { db in
            try DraftPost.fetchOne(db, key: id)
        }
    }

    /// 按状态过滤查询
    func fetch(status: DraftPostStatus) async throws -> [DraftPost] {
        try await db.read { db in
            try DraftPost
                .filter(DraftPost.Columns.status == status)
                .order(DraftPost.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }

    /// 写入新草稿，自动填充 createdAt / updatedAt
    func insert(_ draft: DraftPost) async throws -> DraftPost {
        try await db.write { db in
            var record = draft
            record.createdAt = Date()
            record.updatedAt = Date()
            try record.insert(db)
            return record
        }
    }

    /// 更新草稿，自动刷新 updatedAt
    func update(_ draft: DraftPost) async throws {
        try await db.write { db in
            var record = draft
            record.updatedAt = Date()
            try record.update(db)
        }
    }

    /// 按主键删除草稿
    func delete(id: Int64) async throws {
        try await db.write { db in
            _ = try DraftPost.deleteOne(db, key: id)
        }
    }

    /// 统计草稿总记录数
    func count() async throws -> Int {
        try await db.read { db in
            try DraftPost.fetchCount(db)
        }
    }
}
