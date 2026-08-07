//
//  DatabaseManager.swift
//  Follower
//
//  GRDB 数据库管理器。使用单库多表设计。
//  磁盘创建失败时自动降级到内存数据库，避免启动闪退。

import Foundation
import GRDB

// MARK: - DatabaseManager

/// GRDB 数据库管理器 — 单库多表，磁盘失败自动降级到内存库
final class DatabaseManager: @unchecked Sendable {
    /// 共享单例
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue
    /// 是否使用内存数据库（降级模式）
    let isInMemoryFallback: Bool

    /// 私有 init：尝试磁盘数据库，失败则降级到内存
    private init() {
        var queue: DatabaseQueue?
        var fallback = false

        // 尝试创建磁盘数据库
        if let url = try? DatabaseManager.databaseURL() {
            do {
                let q = try DatabaseQueue(path: url.path)
                try DatabaseManager.runMigrations(on: q)
                queue = q
            } catch {
                NSLog("⚠️ Follower: 磁盘数据库初始化失败: \(error)，降级到内存数据库")
                fallback = true
            }
        } else {
            fallback = true
        }

        // 降级：内存数据库
        if queue == nil {
            do {
                let q = try DatabaseQueue()
                try DatabaseManager.runMigrations(on: q)
                queue = q
                fallback = true
            } catch {
                // 内存数据库不可能失败，但保留保护
                fatalError("Follower: 内存数据库也无法初始化: \(error)")
            }
        }

        self.dbQueue = queue!
        self.isInMemoryFallback = fallback
    }

    // MARK: - Public API

    /// 只读事务 — 可并发执行
    func read<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.read(block)
    }

    /// 写入事务 — 串行化执行
    func write<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }

    /// 批量写入 — 与 write 共用串行队列
    func batchWrite<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }

    // MARK: - Private

    /// 获取 Application Support 下的数据库文件 URL
    private static func databaseURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("Follower", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("follower.sqlite")
    }

    /// 注册并运行数据库迁移
    private static func runMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial_schema") { db in
            try MigrationV1.run(in: db)
        }
        migrator.registerMigration("v2_draft_post") { db in
            try MigrationV2.run(in: db)
        }
        try migrator.migrate(dbQueue)
    }
}
