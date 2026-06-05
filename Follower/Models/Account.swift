//
//  Account.swift
//  Follower
//
//  表示一个已连接的社交媒体账号。

import Foundation
import GRDB

// MARK: - Platform

enum Platform: String, Codable, DatabaseValueConvertible {
    case instagram
    case tiktok
}

// MARK: - AuthState

enum AuthState: String, Codable, DatabaseValueConvertible {
    case authorized
    case expired
    case revoked
}

// MARK: - Account

struct Account: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var platform: Platform
    var username: String
    var displayName: String
    var authState: AuthState
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "account"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Account {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let platform = Column(CodingKeys.platform)
        static let username = Column(CodingKeys.username)
        static let displayName = Column(CodingKeys.displayName)
        static let authState = Column(CodingKeys.authState)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Account> {
    func filter(platform: Platform) -> Self {
        filter(Account.Columns.platform == platform)
    }
    func filter(authState: AuthState) -> Self {
        filter(Account.Columns.authState == authState)
    }
    func filter(username: String) -> Self {
        filter(Account.Columns.username == username)
    }
}
