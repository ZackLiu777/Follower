//
//  AccountRepository.swift
//  Follower
//
//  Account 数据访问层。
//  唯一入口：所有 Account 持久化读写必须经过此 Repository。
//

import Foundation
import GRDB

// MARK: - AccountRepositoryProtocol

/// Account 数据访问协议，定义所有持久化读写操作的统一入口
protocol AccountRepositoryProtocol: Sendable {
    /// 获取全部 Account 列表
    func fetchAll() async throws -> [Account]
    /// 按主键 ID 获取单个 Account
    func fetch(id: Int64) async throws -> Account?
    /// 按平台过滤 Account 列表
    func fetch(platform: Platform) async throws -> [Account]
    /// 插入新 Account，自动设置 createdAt/updatedAt
    func insert(_ account: Account) async throws -> Account
    /// 更新已有 Account，自动刷新 updatedAt
    func update(_ account: Account) async throws
    /// 按主键删除 Account
    func delete(id: Int64) async throws
    /// 返回 Account 总条数
    func count() async throws -> Int
}

// MARK: - AccountRepository

/// AccountRepository 实现，基于 GRDB 提供所有 Account 持久化操作
final class AccountRepository: AccountRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// 查询全部 Account，无分页（数量有限场景下可用）
    func fetchAll() async throws -> [Account] {
        try await db.read { db in
            try Account.fetchAll(db)
        }
    }

    /// 按主键 ID 查询单条 Account
    func fetch(id: Int64) async throws -> Account? {
        try await db.read { db in
            try Account.fetchOne(db, key: id)
        }
    }

    /// 按平台类型过滤查询（Instagram / TikTok 等）
    func fetch(platform: Platform) async throws -> [Account] {
        try await db.read { db in
            try Account
                .filter(Account.Columns.platform == platform)
                .fetchAll(db)
        }
    }

    /// 写入新 Account，自动填充 createdAt / updatedAt
    func insert(_ account: Account) async throws -> Account {
        try await db.write { db in
            var record = account
            record.createdAt = Date()
            record.updatedAt = Date()
            try record.insert(db)
            return record
        }
    }

    /// 更新已有 Account，自动刷新 updatedAt
    func update(_ account: Account) async throws {
        try await db.write { db in
            var record = account
            record.updatedAt = Date()
            try record.update(db)
        }
    }

    /// 按主键删除 Account
    func delete(id: Int64) async throws {
        try await db.write { db in
            _ = try Account.deleteOne(db, key: id)
        }
    }

    /// 统计 Account 总记录数
    func count() async throws -> Int {
        try await db.read { db in
            try Account.fetchCount(db)
        }
    }
}
