//
//  MockInstagramAPIClientTests.swift
//  FollowerTests
//
//  测试账号 Mock 数据测试：
//  确定性 / 哨兵 token / 序列与媒体形态 / 评论一致性 / 分派契约 / 全链路 sync 集成。
//

import Testing
import Foundation
@testable import Follower

/// Mock 数据层测试 — 验证确定性、数据形态与 APIClientResolver 分派契约
struct MockInstagramAPIClientTests {

    // MARK: - 确定性（同 seed 同数据）

    @Test
    func testDeterminism() async throws {
        let a = MockInstagramAPIClient(seed: 42)
        let b = MockInstagramAPIClient(seed: 42)
        let c = MockInstagramAPIClient(seed: 99)

        let userA = try await a.fetchProfile(accessToken: "mock://token")
        let userB = try await b.fetchProfile(accessToken: "mock://token")
        let userC = try await c.fetchProfile(accessToken: "mock://token")
        #expect(userA.followersCount == userB.followersCount)
        #expect(userA.followersCount != userC.followersCount)

        let mediaA = try await a.fetchMedia(accessToken: "mock://token", limit: 100)
        let mediaB = try await b.fetchMedia(accessToken: "mock://token", limit: 100)
        #expect(mediaA.map(\.id) == mediaB.map(\.id))
        #expect(mediaA.map(\.likeCount) == mediaB.map(\.likeCount))
    }

    // MARK: - 哨兵 token（分派依据）

    @Test
    func testSentinelToken() {
        #expect(MockInstagramAPIClient.isMockToken("mock://token"))
        #expect(!MockInstagramAPIClient.isMockToken("IGAA123456789"))
        #expect(!MockInstagramAPIClient.isMockToken("EAABwxyz"))
        #expect(!MockInstagramAPIClient.isMockToken(""))
        #expect(!MockInstagramAPIClient.isMockToken("mock"))
    }

    // MARK: - fetchProfile 一致性

    @Test
    func testFetchProfileConsistency() async throws {
        let client = MockInstagramAPIClient()
        let user = try await client.fetchProfile(accessToken: "mock://token")
        #expect(user.accountType == "BUSINESS")          // 解锁评论管理
        #expect(user.mediaCount == MockInstagramAPIClient.mediaCount)
        #expect((user.followersCount ?? 0) > 8000)
        #expect((user.followersCount ?? 0) < 20000)
        #expect(user.username == "test.user")
    }

    // MARK: - fetchInsights day 序列形态

    @Test
    func testFetchInsightsDaySeries() async throws {
        let client = MockInstagramAPIClient()
        let insights = try await client.fetchInsights(
            accessToken: "mock://token",
            metrics: ["follower_count", "reach", "views"],
            period: "day"
        )
        // 请求的 3 个指标 + 附加互动明细 3 个（likes/comments/shares，趋势聚合用）
        #expect(insights.count == 6)
        for insight in insights {
            #expect(insight.period == "day")
            #expect(insight.values?.count == 730)        // 730 天序列（跨年 → year 窗口有数据）
        }
        // 序列末值 = profile 粉丝数（实例内一致性）
        let user = try await client.fetchProfile(accessToken: "mock://token")
        let follower = try #require(insights.first { $0.name == "follower_count" })
        let lastValue = try #require(follower.values?.last?.value)
        #expect(Int(lastValue) == user.followersCount)

        // 互动序列非全零（历史互动图表数据源；真实 API 路径不请求这些指标）
        for name in ["likes", "comments", "shares"] {
            let series = try #require(insights.first { $0.name == name })
            #expect((series.values ?? []).contains { ($0.value ?? 0) > 0 }, "\(name) 序列应有非零值")
        }
    }

    /// 最后 7 天 follower 净变化为负 → Dashboard 取关列表可展示
    @Test
    func testLastWeekNetNegative() async throws {
        let client = MockInstagramAPIClient()
        let insights = try await client.fetchInsights(
            accessToken: "mock://token",
            metrics: ["follower_count"],
            period: "day"
        )
        let values = try #require(insights.first?.values)
        let lastWeek = values.suffix(7).compactMap { $0.value }
        #expect(lastWeek.count == 7)
        let net = lastWeek.last! - lastWeek.first!
        #expect(net < 0, "最后 7 天净变化应为负（取关列表数据源），实际 \(net)")
    }

    // MARK: - fetchInsights audience_country breakdown 形态

    @Test
    func testCountryBreakdown() async throws {
        let client = MockInstagramAPIClient()
        let insights = try await client.fetchInsights(
            accessToken: "mock://token",
            metrics: ["audience_country"],
            period: "lifetime"
        )
        let country = try #require(insights.first { $0.name == "audience_country" })
        #expect(country.period == "lifetime")
        let breakdowns = try #require(country.totalValue?.breakdowns)
        #expect(breakdowns.count == 8)
        // 百分比和 = 100（GeoDistribution 按占比渲染）
        let sum = breakdowns.compactMap(\.value).reduce(0, +)
        #expect(abs(sum - 100) < 0.001)
    }

    // MARK: - fetchMedia 形态

    @Test
    func testFetchMediaShape() async throws {
        let client = MockInstagramAPIClient()
        let media = try await client.fetchMedia(accessToken: "mock://token", limit: 100)
        #expect(media.count == MockInstagramAPIClient.mediaCount)

        // 三类型齐全
        let types = Set(media.compactMap(\.mediaType))
        #expect(types.contains("IMAGE"))
        #expect(types.contains("VIDEO"))
        #expect(types.contains("CAROUSEL_ALBUM"))

        // 边界用例：1 条爆款（≥20000 赞）+ 2 条零互动（≤2 赞）
        #expect(media.contains { ($0.likeCount ?? 0) >= 20000 })
        #expect(media.filter { ($0.likeCount ?? 99) <= 2 }.count == 2)

        // 时间戳可解析（SyncEngine 依赖）
        for m in media {
            let iso = ISO8601DateFormatter()
            #expect(iso.date(from: m.timestamp ?? "") != nil, "媒体时间戳应为 ISO8601")
        }
    }

    // MARK: - 评论一致性

    /// 评论数量与媒体 comments_count 对齐；未覆盖媒体无评论
    @Test
    func testCommentsConsistency() async throws {
        let client = MockInstagramAPIClient()
        let media = try await client.fetchMedia(accessToken: "mock://token", limit: 100)

        let commented = media.filter { ($0.commentsCount ?? 0) > 0 }
        #expect(commented.count == MockInstagramAPIClient.commentedMediaCount)
        for m in commented {
            let comments = try await client.fetchComments(
                accessToken: "mock://token", mediaID: m.id, limit: 50
            )
            #expect(comments.count == m.commentsCount, "\(m.id) 评论数应与 comments_count 对齐")
            #expect(comments.allSatisfy { !$0.text!.isEmpty })
        }

        let noComment = try #require(media.first { ($0.commentsCount ?? 0) == 0 })
        let empty = try await client.fetchComments(
            accessToken: "mock://token", mediaID: noComment.id, limit: 50
        )
        #expect(empty.isEmpty)
    }

    // MARK: - 回复 / 删除

    @Test
    func testReplyAndDelete() async throws {
        let client = MockInstagramAPIClient()
        let replyID = try await client.replyComment(
            accessToken: "mock://token", mediaID: "17895695668004500", message: "测试回复"
        )
        #expect(!replyID.isEmpty)
        // 删除不抛异常即通过
        try await client.deleteComment(accessToken: "mock://token", commentID: replyID)
    }

    // MARK: - APIClientResolver 分派契约（防回归保险丝）

    /// 契约：真实/OAuth token → real；哨兵 token → mock
    @Test
    func testResolverDispatchContract() {
        let real = InstagramAPIClient()
        let mock = MockInstagramAPIClient()
        let resolver = APIClientResolver(realClient: real, mockClient: mock)

        #expect(resolver.client(for: "IGAA1234567890") as AnyObject === real as AnyObject)
        #expect(resolver.client(for: "EAABwxyz9876") as AnyObject === real as AnyObject)
        #expect(resolver.client(for: "mock://token") as AnyObject === mock as AnyObject)
    }

    // MARK: - RoutingTokenProvider 分派契约（测试账号 token 不落 Keychain）

    /// 测试账号：storeToken no-op（不落 Keychain）、getToken 返回哨兵（Keychain 无值也成立，兼容旧坏账号）；
    /// 真实账号：原样转发 Keychain
    @Test
    func testRoutingTokenProviderDispatch() async throws {
        let db = DatabaseManager(inMemory: true)
        let accountRepo = AccountRepository(db: db)
        let keychain = RecordingTokenProvider()
        let routing = RoutingTokenProvider(keychain: keychain, accountRepo: accountRepo)

        // ── 测试账号 ──
        let testAccount = Account(
            platform: .instagram, username: "test.user", displayName: "Test User",
            authState: .authorized, accountType: "BUSINESS", isTest: true,
            createdAt: Date(), updatedAt: Date()
        )
        let saved = try await accountRepo.insert(testAccount)
        let testId = try #require(saved.id)

        try await routing.storeToken(accountId: testId, accessToken: MockInstagramAPIClient.sentinelToken)
        #expect(keychain.stored.isEmpty, "测试账号 token 不应落 Keychain")
        let got = try await routing.getToken(accountId: testId)
        #expect(got == MockInstagramAPIClient.sentinelToken, "测试账号 getToken 应返回哨兵")

        // ── 真实账号 ──
        let realAccount = Account(
            platform: .instagram, username: "real.user", displayName: "Real User",
            authState: .authorized, createdAt: Date(), updatedAt: Date()
        )
        let savedReal = try await accountRepo.insert(realAccount)
        let realId = try #require(savedReal.id)

        try await routing.storeToken(accountId: realId, accessToken: "IGAA1234567890")
        #expect(keychain.stored[realId] == "IGAA1234567890", "真实账号应落 Keychain")
        #expect(try await routing.getToken(accountId: realId) == "IGAA1234567890")

        // 真实账号未存 token → 转发 Keychain 的 tokenNotFound 错误（不误判为测试账号）
        let bareAccount = Account(
            platform: .instagram, username: "bare.user", displayName: "Bare User",
            authState: .authorized, createdAt: Date(), updatedAt: Date()
        )
        let savedBare = try await accountRepo.insert(bareAccount)
        let bareId = try #require(savedBare.id)
        do {
            _ = try await routing.getToken(accountId: bareId)
            #expect(false, "真实账号无 token 应抛 tokenNotFound")
        } catch is TokenError {
            // 预期
        }
    }
}

/// 记录式内存 TokenProvider — 记录存储内容供断言（仅测试用）
private final class RecordingTokenProvider: TokenProviderProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [Int64: String] = [:]
    var stored: [Int64: String] {
        lock.lock(); defer { lock.unlock() }
        return tokens
    }

    func storeToken(accountId: Int64, accessToken: String) async throws {
        lock.lock(); tokens[accountId] = accessToken; lock.unlock()
    }
    func getToken(accountId: Int64) async throws -> String {
        lock.lock(); defer { lock.unlock() }
        guard let token = tokens[accountId] else { throw TokenError.tokenNotFound }
        return token
    }
    func deleteToken(accountId: Int64) async throws {
        lock.lock(); tokens[accountId] = nil; lock.unlock()
    }
}

// MARK: - 集成：test 账号 sync 全链路（内存库）

/// 测试账号全链路集成 — Mock API → SyncEngine → Ingestion → Aggregation → 数据库
struct TestAccountSyncIntegrationTests {

    /// 内存版 TokenProvider（Keychain 不可用于测试）
    private final class InMemoryTokenProvider: TokenProviderProtocol, @unchecked Sendable {
        private var tokens: [Int64: String] = [:]
        private let lock = NSLock()

        func storeToken(accountId: Int64, accessToken: String) async throws {
            lock.lock(); tokens[accountId] = accessToken; lock.unlock()
        }
        func getToken(accountId: Int64) async throws -> String {
            lock.lock(); defer { lock.unlock() }
            guard let token = tokens[accountId] else { throw TokenError.tokenNotFound }
            return token
        }
        func deleteToken(accountId: Int64) async throws {
            lock.lock(); tokens[accountId] = nil; lock.unlock()
        }
    }

    /// 内存库 + 真实服务 + Mock client → 全链路 sync 后验证各层产物
    @Test
    func testTestAccountFullSync() async throws {
        let db = DatabaseManager(inMemory: true)
        let accountRepo = AccountRepository(db: db)
        let eventRepo = EventRepository(db: db)
        let snapshotRepo = SnapshotRepository(db: db)
        let metricRepo = MetricRepository(db: db)

        let aggregation = AggregationService(
            eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo
        )
        let ingestion = IngestionService(eventRepo: eventRepo, aggregationService: aggregation)
        let mockClient = MockInstagramAPIClient()
        let resolver = APIClientResolver(realClient: InstagramAPIClient(), mockClient: mockClient)
        // 生产链路同款：RoutingTokenProvider（Keychain 用内存实现替代）— 测试账号 token 不落 Keychain
        let tokenProv = RoutingTokenProvider(keychain: InMemoryTokenProvider(), accountRepo: accountRepo)

        let sync = SyncEngine(
            eventRepo: eventRepo, accountRepo: accountRepo,
            ingestionService: ingestion, apiResolver: resolver, tokenProvider: tokenProv
        )

        // 创建 test 账号 + 哨兵 token（与 AccountViewModel.connectTestAccount 一致）
        let account = Account(
            platform: .instagram, username: "test.user", displayName: "Test User",
            authState: .authorized, accountType: "BUSINESS", isTest: true,
            createdAt: Date(), updatedAt: Date()
        )
        let saved = try await accountRepo.insert(account)
        let accountId = try #require(saved.id)
        try await tokenProv.storeToken(accountId: accountId, accessToken: MockInstagramAPIClient.sentinelToken)

        // 全链路 sync（Mock → 管线 → 数据库）
        let result = try await sync.sync(accountId: accountId)
        #expect(result.errors.isEmpty)

        // ── Snapshot：730 天级快照序列 ──
        let snapshots = try await snapshotRepo.fetchAll(accountId: accountId)
        #expect(snapshots.count >= 700, "应有 ≥700 天快照，实际 \(snapshots.count)")

        // 最近 7 天净负 → 取关列表数据源可用
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        let last7 = sorted.suffix(7)
        #expect(last7.count == 7)
        #expect(last7.last!.followersCount - last7.first!.followersCount < 0)

        // ── Metric：6 指标 × 4 窗口全部非空 ──
        for type in TrendsViewModel.visibleMetricTypes {
            for window in [TimeWindow.day, .week, .month, .year] {
                let metrics = try await metricRepo.fetch(
                    accountId: accountId, metricType: type, window: window, limit: 100
                )
                #expect(!metrics.isEmpty, "\(type) \(window) 应有数据")
            }
        }

        // year 窗口 ≥2 个点（730 天跨 3 个自然年）
        let yearMetrics = try await metricRepo.fetch(
            accountId: accountId, metricType: .followerGrowth, window: .year, limit: 10
        )
        #expect(yearMetrics.count >= 2, "year 窗口应 ≥2 点，实际 \(yearMetrics.count)")

        // 历史互动数据落地：day 窗口 averageLikes 存在非零值（mock 附加 likes 序列 → 729 天历史有值）
        let dayLikes = try await metricRepo.fetch(
            accountId: accountId, metricType: .averageLikes, window: .day, limit: 1000
        )
        #expect(dayLikes.contains { $0.value > 0 }, "day averageLikes 应有非零历史值")

        // ── 评论管理：fetch / reply / delete 全通 ──
        let commentService = CommentService(apiResolver: resolver, tokenProvider: tokenProv)
        let media = try await mockClient.fetchMedia(accessToken: "mock://token", limit: 100)
        let firstCommented = try #require(media.first { ($0.commentsCount ?? 0) > 0 })
        let comments = try await commentService.fetchComments(
            accountId: accountId, mediaID: firstCommented.id
        )
        #expect(!comments.isEmpty)

        let replyID = try await commentService.reply(
            accountId: accountId, mediaID: firstCommented.id, message: "集成测试回复"
        )
        #expect(!replyID.isEmpty)

        try await commentService.delete(accountId: accountId, commentID: comments.first!.id)
    }
}
