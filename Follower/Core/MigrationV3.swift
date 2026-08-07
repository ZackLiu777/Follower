//
//  MigrationV3.swift
//  Follower
//
//  v3 数据库迁移：
//  - account 增加 isTest 列（测试账号标记，仅 UI 语义，不参与 API 分派）
//

import Foundation
import GRDB

// MARK: - MigrationV3

/// v3 数据库迁移 — 测试账号标记
enum MigrationV3 {
    /// 执行 v3 迁移：account 增加 isTest 列（幂等：已存在则跳过）
    nonisolated static func run(in db: Database) throws {

        // MARK: account — 增加 isTest 列（幂等：已存在则跳过）
        let accountColumns = try db.columns(in: "account")
        if !accountColumns.contains(where: { $0.name == "isTest" }) {
            try db.alter(table: "account") { t in
                t.add(column: "isTest", .boolean).notNull().defaults(to: false)
            }
        }
    }
}
