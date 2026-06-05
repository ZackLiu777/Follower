//
//  DatabaseManager.swift
//  Follower
//
//  GRDB 数据库管理器。使用单库多表设计。
//  磁盘创建失败时自动降级到内存数据库，避免启动闪退。

import Foundation
import GRDB

// MARK: - DatabaseManager

final class DatabaseManager: @unchecked Sendable {
    /// 共享单例
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue
    /// 是否使用内存数据库（降级模式）
    let isInMemoryFallback: Bool

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

    func read<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.read(block)
    }

    func write<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }

    func batchWrite<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }

    // MARK: - Private

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

    private static func runMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial_schema") { db in
            try MigrationV1.run(in: db)
        }
        try migrator.migrate(dbQueue)
    }
}
