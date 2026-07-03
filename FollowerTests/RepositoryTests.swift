//
//  RepositoryTests.swift
//  FollowerTests
//
//  Repository 层集成测试。

import Testing
import Foundation
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
