//
//  RepositoryTests.swift
//  FollowerTests
//
//  Repository 层集成测试。

import Testing
import Foundation
import GRDB
@testable import Follower

/// Unit tests for Repository layer — covers Account, Event, Snapshot, Metric, and PremiumFeature repositories
struct RepositoryTests {
    let db: DatabaseManager
    let accountRepo: AccountRepository
    let eventRepo: EventRepository
    let snapshotRepo: SnapshotRepository
    let metricRepo: MetricRepository
    let premiumRepo: PremiumFeatureRepository

    /// 测试准备 — 配置数据库和仓库实例
    init() {
        db = DatabaseManager.shared
        accountRepo = AccountRepository(db: db)
        eventRepo = EventRepository(db: db)
        snapshotRepo = SnapshotRepository(db: db)
        metricRepo = MetricRepository(db: db)
        premiumRepo = PremiumFeatureRepository(db: db)
    }

    // MARK: - Account Repository

    /// 插入 Account 后按 ID 查询 → 返回的 username 匹配
    @Test
    func testAccountInsertAndFetch() async throws {
        let account = Account(platform: .instagram, username: "u1_\(UUID())", displayName: "U1", authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await accountRepo.insert(account)
        guard let id = saved.id else {
            #expect(false, "Insert should return id")
            return
        }
        let fetched = try await accountRepo.fetch(id: id)
        #expect(fetched?.username == account.username)
    }

    /// 插入 Account → count 自增 1
    @Test
    func testAccountCount() async throws {
        let before = try await accountRepo.count()
        let a = Account(platform: .instagram, username: "ct_\(UUID())", displayName: "C", authState: .authorized, createdAt: Date(), updatedAt: Date())
        _ = try await accountRepo.insert(a)
        let after = try await accountRepo.count()
        #expect(after == before + 1)
    }

    /// 删除 Account → fetch 返回 nil
    @Test
    func testAccountDelete() async throws {
        let a = Account(platform: .instagram, username: "del2_\(UUID())", displayName: "D", authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await accountRepo.insert(a)
        guard let id = saved.id else {
            #expect(false, "Insert should return id")
            return
        }
        try await accountRepo.delete(id: id)
        let fetched = try await accountRepo.fetch(id: id)
        #expect(fetched == nil)
    }

    // MARK: - Event Repository

    /// 插入单个 Event → saved.id 不为 nil
    @Test
    func testEventInsert() async throws {
        let accountId = try await createAccount()
        let event = Event(accountId: accountId, eventType: .profileSnapshot, payload: Data("p".utf8), source: .api, observedAt: Date(), createdAt: Date())
        let saved = try await eventRepo.insert(event)
        #expect(saved.id != nil)
    }

    /// 批量插入 5 个 Event → 返回 count 为 5
    @Test
    func testEventBatchInsert() async throws {
        let accountId = try await createAccount()
        let events = (0..<5).map { _ in
            Event(accountId: accountId, eventType: .followerChange, payload: Data("x".utf8), source: .api, observedAt: Date(), createdAt: Date())
        }
        let saved = try await eventRepo.insertBatch(events)
        #expect(saved.count == 5)
    }

    /// 按类型查询 Event → 仅返回匹配类型的记录
    @Test
    func testEventFetchByType() async throws {
        let accountId = try await createAccount()
        let e1 = Event(accountId: accountId, eventType: .profileSnapshot, payload: Data("a".utf8), source: .api, observedAt: Date(), createdAt: Date())
        let e2 = Event(accountId: accountId, eventType: .followerChange, payload: Data("b".utf8), source: .api, observedAt: Date(), createdAt: Date())
        _ = try await eventRepo.insertBatch([e1, e2])
        let snapshots = try await eventRepo.fetch(accountId: accountId, eventType: .profileSnapshot, limit: 10)
        #expect(snapshots.count == 1)
    }

    // MARK: - Snapshot Repository

    /// Upsert 相同 day 的 Snapshot → id 不变且最新数据覆盖
    @Test
    func testSnapshotUpsertReplacesExisting() async throws {
        let accountId = try await createAccount()
        let day = Calendar.current.startOfDay(for: Date())
        let s1 = Snapshot(accountId: accountId, followersCount: 100, followingCount: 10, mediaCount: 5, engagementRate: 0.01, totalLikes: 50, totalComments: 5, totalShares: 2, totalViews: 200, observedAt: day, createdAt: Date())
        let first = try await snapshotRepo.upsert(s1)
        let s2 = Snapshot(accountId: accountId, followersCount: 200, followingCount: 10, mediaCount: 5, engagementRate: 0.02, totalLikes: 100, totalComments: 10, totalShares: 4, totalViews: 400, observedAt: day, createdAt: Date())
        let second = try await snapshotRepo.upsert(s2)

        #expect(first.id == second.id, "Upsert should update existing record")
        let latest = try await snapshotRepo.latest(accountId: accountId)
        #expect(latest?.followersCount == 200)
    }

    // MARK: - Metric Repository

    /// Upsert 相同 metric → id 不变且 value 更新
    @Test
    func testMetricUpsertReplacesExisting() async throws {
        let accountId = try await createAccount()
        let day = Calendar.current.startOfDay(for: Date())
        let m1 = Metric(accountId: accountId, metricType: .followerGrowth, value: 10, window: .day, observedAt: day, createdAt: Date())
        let r1 = try await metricRepo.upsert(m1)
        let m2 = Metric(accountId: accountId, metricType: .followerGrowth, value: 20, window: .day, observedAt: day, createdAt: Date())
        let r2 = try await metricRepo.upsert(m2)
        #expect(r1.id == r2.id, "Upsert should update existing metric")
    }

    /// 批量 upsert 同一复合键 3 次 → 仍只有 1 行（幂等，不依赖唯一索引存在）
    /// 回归防护：INSERT OR REPLACE 在索引缺失时退化为 INSERT 会导致刷新后图表重复
    @Test
    func testMetricUpsertBatchIsIdempotent() async throws {
        let memDB = DatabaseManager(inMemory: true)
        let memAccountRepo = AccountRepository(db: memDB)
        let memMetricRepo = MetricRepository(db: memDB)

        let account = Account(platform: .instagram, username: "batch_\(UUID())", displayName: "B",
                              authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await memAccountRepo.insert(account)
        let accountId = try #require(saved.id)
        let day = Calendar.current.startOfDay(for: Date())

        let batch = [Metric(accountId: accountId, metricType: .followerGrowth, value: 100,
                            window: .day, observedAt: day, createdAt: Date())]
        _ = try await memMetricRepo.upsertBatch(batch)
        _ = try await memMetricRepo.upsertBatch(batch)
        _ = try await memMetricRepo.upsertBatch(batch)

        let rows = try await memMetricRepo.fetch(accountId: accountId, metricType: .followerGrowth,
                                                 window: .day, limit: 10)
        #expect(rows.count == 1, "重复 upsertBatch 不应产生重复行，实际 \(rows.count)")
    }

    /// v5 迁移：清理同键重复行（模拟索引缺失时期的历史脏数据）+ 补齐唯一索引
    @Test
    func testMigrationV5DeduplicatesAndRebuildsIndex() async throws {
        let memDB = DatabaseManager(inMemory: true)
        let memAccountRepo = AccountRepository(db: memDB)

        let account = Account(platform: .instagram, username: "v5_\(UUID())", displayName: "V5",
                              authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await memAccountRepo.insert(account)
        let accountId = try #require(saved.id)
        let day = Calendar.current.startOfDay(for: Date())

        // 1. 模拟索引缺失的历史库：DROP 唯一索引
        try await memDB.write { db in
            try db.execute(sql: "DROP INDEX IF EXISTS idx_metric_account_type_window")
        }

        // 2. 绕过 upsertBatch 直接 INSERT 同键 3 行（模拟旧版本 REPLACE 退化为 INSERT 的脏数据）
        try await memDB.write { db in
            for _ in 0..<3 {
                try db.execute(
                    sql: "INSERT INTO metric (accountId, metricType, value, window, observedAt, createdAt) VALUES (?,?,?,?,?,?)",
                    arguments: [accountId, MetricType.followerGrowth.rawValue, 100, TimeWindow.day.rawValue, day, Date()]
                )
            }
        }

        // 3. 跑 v5 迁移：去重 + 建索引
        try await memDB.write { db in
            try V5MetricDedupIndex.run(in: db)
        }

        // 4. 验证：同键只剩 1 行
        let rows = try await memDB.read { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .filter(Metric.Columns.metricType == MetricType.followerGrowth)
                .filter(Metric.Columns.window == TimeWindow.day)
                .fetchAll(db)
        }
        #expect(rows.count == 1, "v5 去重后同键应只剩 1 行，实际 \(rows.count)")

        // 5. 验证：唯一索引已重建 → 直接 INSERT 同键会抛唯一约束错误
        let indexExists = try await memDB.read { db in
            try db.indexes(on: "metric").contains { $0.name == "idx_metric_account_type_window" }
        }
        #expect(indexExists, "v5 应补齐唯一索引")
        try await memDB.write { db in
            #expect(throws: DatabaseError.self) {
                try db.execute(
                    sql: "INSERT INTO metric (accountId, metricType, value, window, observedAt, createdAt) VALUES (?,?,?,?,?,?)",
                    arguments: [accountId, MetricType.followerGrowth.rawValue, 200, TimeWindow.day.rawValue, day, Date()]
                )
            }
        }
    }

    /// v7 迁移：旧库浮点 Metric 值换算为整数语义
    /// - engagementTrend 0~1 比率 → 万分比整数（0.0543 → 543）
    /// - 计数类浮点 → ROUND 取整（8250.5 → 8251）
    @Test
    func testMigrationV7ConvertsLegacyDoubleValues() async throws {
        let memDB = DatabaseManager(inMemory: true)
        let memAccountRepo = AccountRepository(db: memDB)

        let account = Account(platform: .instagram, username: "v7_\(UUID())", displayName: "V7",
                              authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await memAccountRepo.insert(account)
        let accountId = try #require(saved.id)
        let day = Calendar.current.startOfDay(for: Date())

        // 1. 模拟旧库 REAL 值：互动率存比率、计数类存浮点
        try await memDB.write { db in
            try db.execute(
                sql: "INSERT INTO metric (accountId, metricType, value, window, observedAt, createdAt) VALUES (?,?,?,?,?,?)",
                arguments: [accountId, MetricType.engagementTrend.rawValue, 0.0543, TimeWindow.day.rawValue, day, Date()]
            )
            try db.execute(
                sql: "INSERT INTO metric (accountId, metricType, value, window, observedAt, createdAt) VALUES (?,?,?,?,?,?)",
                arguments: [accountId, MetricType.followerGrowth.rawValue, 8250.5, TimeWindow.day.rawValue, day, Date()]
            )
        }

        // 2. 跑 v7 迁移：换算为整数
        try await memDB.write { db in
            try V7MetricIntegerValues.run(in: db)
        }

        // 3. 验证：0.0543 → 543（万分比），8250.5 → 8251（ROUND）
        let rows = try await memDB.read { db in
            try Metric
                .filter(Metric.Columns.accountId == accountId)
                .order(Metric.Columns.metricType)
                .fetchAll(db)
        }
        let byType = Dictionary(uniqueKeysWithValues: rows.map { ($0.metricType, $0.value) })
        #expect(byType[.engagementTrend] == 543, "0.0543 should become 543 basis points")
        #expect(byType[.followerGrowth] == 8251, "8250.5 should round to 8251")
    }

    // MARK: - Premium Feature Repository

    /// 设置 Premium 开关 → isEnabled 反映最新状态
    @Test
    func testPremiumFeatureIsEnabled() async throws {
        try await premiumRepo.setEnabled(true, for: .trendPrediction)
        let enabled = try await premiumRepo.isEnabled(key: .trendPrediction)
        #expect(enabled)
        try await premiumRepo.setEnabled(false, for: .trendPrediction)
        let disabled = try await premiumRepo.isEnabled(key: .trendPrediction)
        #expect(!disabled)
    }

    /// Premium 已过期 → isEnabled 返回 false
    @Test
    func testPremiumFeatureExpiry() async throws {
        try await premiumRepo.setEnabled(true, expiresAt: Date().addingTimeInterval(-1), for: .csvExport)
        let enabled = try await premiumRepo.isEnabled(key: .csvExport)
        #expect(!enabled, "Expired feature should be disabled")
    }

    // MARK: - Helper

    /// 创建测试用 Account，预填充默认值
    private func createAccount() async throws -> Int64 {
        let a = Account(platform: .instagram, username: "repo_\(UUID())", displayName: "R", authState: .authorized, createdAt: Date(), updatedAt: Date())
        let saved = try await accountRepo.insert(a)
        guard let id = saved.id else { throw TestError.noId }
        return id
    }

    enum TestError: Error { case noId }
}
