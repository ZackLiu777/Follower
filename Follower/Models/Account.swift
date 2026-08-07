//
//  Account.swift
//  Follower
//
//  表示一个已连接的社交媒体账号。

import Foundation
import GRDB

// MARK: - Platform

/// 支持的社交媒体平台
enum Platform: String, Codable, DatabaseValueConvertible {
    case instagram
    case tiktok
}

// MARK: - AuthState

/// 账号授权状态：已授权 / 已过期 / 已撤销
enum AuthState: String, Codable, DatabaseValueConvertible {
    case authorized
    case expired
    case revoked
}

// MARK: - Account

/// 已连接社交媒体账号的持久化模型
struct Account: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var platform: Platform
    var username: String
    var displayName: String
    var authState: AuthState
    /// Instagram 账号类型：PERSONAL / BUSINESS / CREATOR（评论管理仅对后两者开放）
    var accountType: String?
    /// 测试账号标记（仅 UI 语义：徽章展示与连接流程限定；不参与 API 分派）
    var isTest: Bool = false
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "account"

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Account {
    /// GRDB 列名映射，避免字符串硬编码
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let platform = Column(CodingKeys.platform)
        static let username = Column(CodingKeys.username)
        static let displayName = Column(CodingKeys.displayName)
        static let authState = Column(CodingKeys.authState)
        static let accountType = Column(CodingKeys.accountType)
        static let isTest = Column(CodingKeys.isTest)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Account> {
    /// 按平台过滤查询
    func filter(platform: Platform) -> Self {
        filter(Account.Columns.platform == platform)
    }
    /// 按授权状态过滤
    func filter(authState: AuthState) -> Self {
        filter(Account.Columns.authState == authState)
    }
    /// 按用户名精确过滤
    func filter(username: String) -> Self {
        filter(Account.Columns.username == username)
    }
}
