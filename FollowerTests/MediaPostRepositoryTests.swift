//
//  MediaPostRepositoryTests.swift
//  FollowerTests
//
//  MediaPost 持久化（v4）测试：
//  upsert 幂等（同 igMediaID 替换不重复）/ 最近查询排序与 limit / 删账号级联清理。
//

import Testing
import Foundation
@testable import Follower

/// MediaPost 数据层测试 — 帖子持久化语义（App 重启不丢数据的数据源）
struct MediaPostRepositoryTests {

    let db: DatabaseManager
    let mediaRepo: MediaPostRepository
    let accountRepo: AccountRepository

    init() {
        // 内存库：测试数据不落盘、用例间互不污染
        db = DatabaseManager(inMemory: true)
        mediaRepo = MediaPostRepository(db: db)
        accountRepo = AccountRepository(db: db)
    }

    /// 辅助：创建账号并返回其 id
    private func makeAccount(username: String = "post_\(UUID())") async throws -> Int64 {
        let account = Account(
            platform: .instagram, username: username, displayName: "P",
            authState: .authorized, createdAt: Date(), updatedAt: Date()
        )
        let saved = try await accountRepo.insert(account)
        return try #require(saved.id)
    }

    /// 批量 upsert → 按日期降序 + limit 生效
    @Test
    func testUpsertAndFetchRecent() async throws {
        let accountId = try await makeAccount()
        let base = Date()
        let posts = (0..<3).map { i in
            MediaPost(
                id: Int64(100 + i), accountId: accountId, igMediaID: "ig_\(i)",
                type: .image, date: base.addingTimeInterval(TimeInterval(i * 3600)),
                likes: 10 + i, comments: 2, caption: "post \(i)",
                mediaURL: nil, permalink: "https://instagram.com/p/\(i)"
            )
        }
        _ = try await mediaRepo.upsertBatch(accountId: accountId, media: posts)

        let recent = try await mediaRepo.fetchRecent(accountId: accountId, limit: 2)
        #expect(recent.count == 2)
        #expect(recent.first?.igMediaID == "ig_2", "最新帖子应在最前（日期降序）")
        #expect(recent.last?.igMediaID == "ig_1")
        #expect(recent.allSatisfy { $0.accountId == accountId })
    }

    /// upsert 幂等：同 igMediaID 重复写入 → 替换而非追加（依赖唯一键）
    @Test
    func testUpsertIsIdempotent() async throws {
        let accountId = try await makeAccount()
        let date = Date()
        let post = MediaPost(
            id: 200, accountId: accountId, igMediaID: "ig_same",
            type: .video, date: date, likes: 5, comments: 1,
            caption: "v1", mediaURL: nil, permalink: nil
        )
        _ = try await mediaRepo.upsertBatch(accountId: accountId, media: [post])

        // 模拟同帖再次同步：点赞数变化
        let newer = MediaPost(
            id: 200, accountId: accountId, igMediaID: "ig_same",
            type: .video, date: date, likes: 99, comments: 3,
            caption: "v2", mediaURL: nil, permalink: nil
        )
        _ = try await mediaRepo.upsertBatch(accountId: accountId, media: [newer])

        let all = try await mediaRepo.fetchRecent(accountId: accountId, limit: 10)
        #expect(all.count == 1, "同 igMediaID 重复同步应替换而非追加，实际 \(all.count)")
        #expect(all.first?.likes == 99, "替换后应为新值")
    }

    /// 删账号 → 帖子级联清理（外键 ON DELETE CASCADE）
    @Test
    func testCascadeDeleteWithAccount() async throws {
        let accountId = try await makeAccount(username: "cascade_post_\(UUID())")
        let post = MediaPost(
            id: 300, accountId: accountId, igMediaID: "ig_cascade",
            type: .image, date: Date(), likes: 1, comments: 0,
            caption: "c", mediaURL: nil, permalink: nil
        )
        _ = try await mediaRepo.upsertBatch(accountId: accountId, media: [post])
        #expect(try await mediaRepo.fetchRecent(accountId: accountId, limit: 10).count == 1)

        try await accountRepo.delete(id: accountId)
        #expect(try await mediaRepo.fetchRecent(accountId: accountId, limit: 10).isEmpty,
                "删除账号应级联清理帖子")
    }
}
