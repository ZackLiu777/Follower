//
//  MediaKitTests.swift
//  Follower
//
//  媒体包测试：数据收集映射 + PDF 生成管线（内存库，零网络）。
//

import Testing
import Foundation
import PDFKit
@testable import Follower

/// 媒体包数据收集 + PDF 生成（串行：共享内存库布局）
@Suite(.serialized)
struct MediaKitTests {

    /// 测试环境：内存库 + 各 Repository + 测试账号
    private struct Env {
        let db = DatabaseManager(inMemory: true)
        let accountRepo: AccountRepository
        let snapshotRepo: SnapshotRepository
        let metricRepo: MetricRepository
        let mediaRepo: MediaPostRepository

        init() {
            accountRepo = AccountRepository(db: db)
            snapshotRepo = SnapshotRepository(db: db)
            metricRepo = MetricRepository(db: db)
            mediaRepo = MediaPostRepository(db: db)
        }

        func makeProvider() -> MediaKitDataProvider {
            MediaKitDataProvider(
                accountRepo: accountRepo, snapshotRepo: snapshotRepo,
                metricRepo: metricRepo, mediaRepo: mediaRepo
            )
        }

        func insertAccount() async throws -> Int64 {
            let account = Account(
                platform: .instagram, username: "test.user", displayName: "Test User",
                authState: .authorized, accountType: "CREATOR",
                createdAt: Date(), updatedAt: Date()
            )
            let saved = try await accountRepo.insert(account)
            return try #require(saved.id)
        }
    }

    /// 全量数据 → collect 映射正确（指标 6 行、周序列、Top 排序、类型分布）
    @Test
    func testCollectMapsFullData() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()

        // 快照 + 周指标 + 日指标 + 帖子
        try await env.snapshotRepo.upsert(Snapshot(
            accountId: accountId, followersCount: 1200, followingCount: 300, mediaCount: 10,
            engagementRate: 0.05, totalLikes: 60, totalComments: 8, totalShares: 2, totalViews: 500,
            observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .followerGrowth, value: 1000,
            window: .week, observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .averageLikes, value: 30,
            window: .day, observedAt: Date(), createdAt: Date()
        ))
        let postA = MediaPost(
            id: 1, accountId: accountId, igMediaID: "1", type: .image, date: Date(),
            likes: 200, comments: 10, caption: "", mediaURL: nil, permalink: nil
        )
        let postB = MediaPost(
            id: 2, accountId: accountId, igMediaID: "2", type: .video, date: Date(),
            likes: 50, comments: 2, caption: "", mediaURL: nil, permalink: nil
        )
        try await env.mediaRepo.upsertBatch(accountId: accountId, media: [postA, postB])

        let data = try await env.makeProvider().collect(accountId: accountId)

        // 指标 6 行 + 快照口径
        #expect(data.metricRows.count == 6)
        #expect(data.metricRows.first!.formattedValue == "1.2k", "粉丝数应为 1.2k")
        #expect(data.metricRows[3].formattedValue == "60", "平均赞应为 60")

        // 周序列 1 点
        #expect(data.weeklyGrowth.count == 1)
        #expect(data.weeklyGrowth.first!.followers == 1000)

        // Top 排序：点赞降序
        #expect(data.topPosts.map(\.igMediaID) == ["1", "2"])

        // 类型分布
        #expect(data.postTypeCounts.count == 2)

        // 互动序列
        #expect(data.avgLikesSeries == [30.0])

        // 趋势统计序列：仅 .averageLikes 有数据 → dict 只有该键
        #expect(Array(data.trendSeries.keys) == [.averageLikes])
        #expect(data.trendSeries[.averageLikes] == [30.0])

        // 周柱状序列：仅 .followerGrowth 有周数据
        #expect(Array(data.weeklySeries.keys) == [.followerGrowth])
        #expect(data.weeklySeries[.followerGrowth] == [1000.0])

        // 决策建议：有快照 → 至少生成 4 张卡片（CardGenerator 兜底）
        #expect(data.actionCards.count >= 4)
    }

    /// 无任何数据（仅账号）→ collect 不抛错、指标全占位、序列空
    @Test
    func testCollectWithEmptyData() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()

        let data = try await env.makeProvider().collect(accountId: accountId)
        #expect(data.snapshot == nil)
        #expect(data.metricRows.count == 6)
        #expect(data.metricRows.first!.formattedValue == "—")
        #expect(data.weeklyGrowth.isEmpty)
        #expect(data.topPosts.isEmpty)
        #expect(data.postTypeCounts.isEmpty)
    }

    /// 账号不存在 → throw
    @Test
    func testCollectAccountNotFoundThrows() async {
        let env = Env()
        await #expect(throws: MediaKitError.self) {
            _ = try await env.makeProvider().collect(accountId: 999)
        }
    }

    /// 全量数据 + professional 模板 → 10 页（封面+指标+增长+内容+互动+趋势柱状+趋势×2+建议+结语）
    @Test
    func testGeneratePDFFullData() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()
        try await env.snapshotRepo.upsert(Snapshot(
            accountId: accountId, followersCount: 1200, followingCount: 300, mediaCount: 10,
            engagementRate: 0.05, totalLikes: 60, totalComments: 8, totalShares: 2, totalViews: 500,
            observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .followerGrowth, value: 1000,
            window: .week, observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .averageLikes, value: 30,
            window: .day, observedAt: Date(), createdAt: Date()
        ))
        let postA = MediaPost(
            id: 1, accountId: accountId, igMediaID: "1", type: .image, date: Date(),
            likes: 200, comments: 10, caption: "", mediaURL: nil, permalink: nil
        )
        try await env.mediaRepo.upsertBatch(accountId: accountId, media: [postA])

        let data = try await env.makeProvider().collect(accountId: accountId)
        let generator = MediaKitPDFGenerator()
        let url = try generator.generate(data: data, template: .professional)

        let fileData = try Data(contentsOf: url)
        #expect(!fileData.isEmpty, "PDF 文件不应为空")
        #expect(fileData.prefix(5) == Data("%PDF-".utf8), "应为有效 PDF 文件头")

        // 页数：全量数据 + professional → 10 页
        let document = PDFDocument(data: fileData)
        #expect(document?.pageCount == 10, "professional 全量应 10 页，实际 \(document?.pageCount ?? -1)")
    }

    /// minimal 模板 → 固定 3 页（封面+指标+结语），即使数据齐全也不出内容页
    @Test
    func testGeneratePDFMinimalTemplate() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()
        try await env.snapshotRepo.upsert(Snapshot(
            accountId: accountId, followersCount: 1200, followingCount: 300, mediaCount: 10,
            engagementRate: 0.05, totalLikes: 60, totalComments: 8, totalShares: 2, totalViews: 500,
            observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .followerGrowth, value: 1000,
            window: .week, observedAt: Date(), createdAt: Date()
        ))
        let postA = MediaPost(
            id: 1, accountId: accountId, igMediaID: "1", type: .image, date: Date(),
            likes: 200, comments: 10, caption: "", mediaURL: nil, permalink: nil
        )
        try await env.mediaRepo.upsertBatch(accountId: accountId, media: [postA])

        let data = try await env.makeProvider().collect(accountId: accountId)
        let generator = MediaKitPDFGenerator()
        let url = try generator.generate(data: data, template: .minimal)

        let fileData = try Data(contentsOf: url)
        #expect(fileData.prefix(5) == Data("%PDF-".utf8))
        let document = PDFDocument(data: fileData)
        #expect(document?.pageCount == 3, "minimal 应固定 3 页，实际 \(document?.pageCount ?? -1)")
    }

    /// creative 模板 → 与 professional 相同页数（封面视觉不同，不影响页数）
    @Test
    func testGeneratePDFCreativeTemplate() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()
        try await env.snapshotRepo.upsert(Snapshot(
            accountId: accountId, followersCount: 1200, followingCount: 300, mediaCount: 10,
            engagementRate: 0.05, totalLikes: 60, totalComments: 8, totalShares: 2, totalViews: 500,
            observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .followerGrowth, value: 1000,
            window: .week, observedAt: Date(), createdAt: Date()
        ))
        try await env.metricRepo.upsert(Metric(
            accountId: accountId, metricType: .averageLikes, value: 30,
            window: .day, observedAt: Date(), createdAt: Date()
        ))

        let data = try await env.makeProvider().collect(accountId: accountId)
        let generator = MediaKitPDFGenerator()
        let url = try generator.generate(data: data, template: .creative)

        let fileData = try Data(contentsOf: url)
        let document = PDFDocument(data: fileData)
        // 封面+指标+增长+互动+趋势柱状+趋势×2+建议+结语 = 9 页（无帖子 → 内容页跳过）
        #expect(document?.pageCount == 9, "creative（无帖子）应 9 页，实际 \(document?.pageCount ?? -1)")
    }

    /// 空数据 → 生成 PDF 降级页数（封面+指标+结语 = 3 页），不崩溃
    @Test
    func testGeneratePDFEmptyData() async throws {
        let env = Env()
        let accountId = try await env.insertAccount()

        let data = try await env.makeProvider().collect(accountId: accountId)
        let generator = MediaKitPDFGenerator()
        let url = try generator.generate(data: data)

        let fileData = try Data(contentsOf: url)
        #expect(fileData.prefix(5) == Data("%PDF-".utf8))
        let document = PDFDocument(data: fileData)
        #expect(document?.pageCount == 3, "空数据应降级为 3 页，实际 \(document?.pageCount ?? -1)")
    }
}
