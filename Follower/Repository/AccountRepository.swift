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

protocol AccountRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Account]
    func fetch(id: Int64) async throws -> Account?
    func fetch(platform: Platform) async throws -> [Account]
    func insert(_ account: Account) async throws -> Account
    func update(_ account: Account) async throws
    func delete(id: Int64) async throws
    func count() async throws -> Int
}

// MARK: - AccountRepository

final class AccountRepository: AccountRepositoryProtocol {
    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    func fetchAll() async throws -> [Account] {
        try await db.read { db in
            try Account.fetchAll(db)
        }
    }

    func fetch(id: Int64) async throws -> Account? {
        try await db.read { db in
            try Account.fetchOne(db, key: id)
        }
    }

    func fetch(platform: Platform) async throws -> [Account] {
        try await db.read { db in
            try Account
                .filter(Account.Columns.platform == platform)
                .fetchAll(db)
        }
    }

    func insert(_ account: Account) async throws -> Account {
        try await db.write { db in
            var record = account
            record.createdAt = Date()
            record.updatedAt = Date()
            try record.insert(db)
            return record
        }
    }

    func update(_ account: Account) async throws {
        try await db.write { db in
            var record = account
            record.updatedAt = Date()
            try record.update(db)
        }
    }

    func delete(id: Int64) async throws {
        try await db.write { db in
            _ = try Account.deleteOne(db, key: id)
        }
    }

    func count() async throws -> Int {
        try await db.read { db in
            try Account.fetchCount(db)
        }
    }
}
