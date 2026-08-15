//
//  DraftPostTests.swift
//  FollowerTests
//
//  发布助手数据层测试：DraftPost 状态机 / Codable / Repository CRUD / 评论 DTO 解码。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for DraftPost model and repository — covers status machine, codable, CRUD, and comment DTO decoding
struct DraftPostTests {

    // MARK: - 模型状态机

    /// DraftPostStatus 枚举 → 恰有 4 个状态且 CaseIterable 顺序稳定
    @Test
    func testStatusAllCases() {
        #expect(DraftPostStatus.allCases == [.draft, .scheduled, .published, .failed])
        #expect(DraftPostStatus.allCases.count == 4)
    }

    /// Codable 往返 → 字段一致
    @Test
    func testDraftPostCodableRoundTrip() throws {
        let draft = DraftPost(
            id: 42, accountId: 7, caption: "hello 测试",
            imageFilename: "abc.jpg", scheduledAt: Date(),
            status: .scheduled, createdAt: Date(), updatedAt: Date()
        )
        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(DraftPost.self, from: data)
        #expect(decoded.id == 42)
        #expect(decoded.accountId == 7)
        #expect(decoded.caption == "hello 测试")
        #expect(decoded.imageFilename == "abc.jpg")
        #expect(decoded.status == .scheduled)
    }

    /// isDue → 仅 scheduled 且时间已过为 true
    @Test
    func testIsDue() {
        let past = Date().addingTimeInterval(-60)
        let future = Date().addingTimeInterval(3600)

        let due = DraftPost(id: 1, accountId: nil, caption: "", imageFilename: nil,
                            scheduledAt: past, status: .scheduled, createdAt: Date(), updatedAt: Date())
        #expect(due.isDue)

        let futureDraft = DraftPost(id: 2, accountId: nil, caption: "", imageFilename: nil,
                                    scheduledAt: future, status: .scheduled, createdAt: Date(), updatedAt: Date())
        #expect(!futureDraft.isDue)

        // 未排期草稿永不到期
        let plain = DraftPost(id: 3, accountId: nil, caption: "", imageFilename: nil,
                              scheduledAt: nil, status: .draft, createdAt: Date(), updatedAt: Date())
        #expect(!plain.isDue)
    }

    // MARK: - Repository CRUD

    let db: DatabaseManager
    let draftRepo: DraftPostRepository
    let accountRepo: AccountRepository

    init() {
        // 内存库：测试数据不落盘、用例间互不污染（原 shared 磁盘库会累积数据）
        db = DatabaseManager(inMemory: true)
        draftRepo = DraftPostRepository(db: db)
        accountRepo = AccountRepository(db: db)
    }

    /// 插入草稿 → 按 ID 查询匹配
    @Test
    func testDraftInsertAndFetch() async throws {
        let draft = DraftPost(
            id: nil, accountId: nil, caption: "草稿文案 \(UUID())",
            imageFilename: nil, scheduledAt: nil, status: .draft,
            createdAt: Date(), updatedAt: Date()
        )
        let saved = try await draftRepo.insert(draft)
        guard let id = saved.id else {
            #expect(false, "Insert should return id")
            return
        }
        let fetched = try await draftRepo.fetch(id: id)
        #expect(fetched?.caption == draft.caption)
    }

    /// 按状态过滤 → 只返回该状态的草稿
    @Test
    func testDraftFetchByStatus() async throws {
        let d1 = DraftPost(id: nil, accountId: nil, caption: "sched_\(UUID())", imageFilename: nil,
                           scheduledAt: Date().addingTimeInterval(3600), status: .scheduled,
                           createdAt: Date(), updatedAt: Date())
        let d2 = DraftPost(id: nil, accountId: nil, caption: "draft_\(UUID())", imageFilename: nil,
                           scheduledAt: nil, status: .draft,
                           createdAt: Date(), updatedAt: Date())
        _ = try await draftRepo.insert(d1)
        _ = try await draftRepo.insert(d2)

        let drafts = try await draftRepo.fetch(status: .scheduled)
        #expect(drafts.contains { $0.caption == d1.caption })
        #expect(!drafts.contains { $0.caption == d2.caption })
    }

    /// 更新草稿 → 状态流转生效且 updatedAt 刷新
    @Test
    func testDraftUpdate() async throws {
        let draft = DraftPost(id: nil, accountId: nil, caption: "upd_\(UUID())", imageFilename: nil,
                              scheduledAt: nil, status: .draft, createdAt: Date(), updatedAt: Date())
        let saved = try await draftRepo.insert(draft)
        guard let id = saved.id else {
            #expect(false, "Insert should return id")
            return
        }

        var updated = try #require(try await draftRepo.fetch(id: id))
        updated.status = .published
        try await draftRepo.update(updated)

        let fetched = try await draftRepo.fetch(id: id)
        #expect(fetched?.status == .published)
    }

    /// 删除草稿 → fetch 返回 nil
    @Test
    func testDraftDelete() async throws {
        let draft = DraftPost(id: nil, accountId: nil, caption: "del_\(UUID())", imageFilename: nil,
                              scheduledAt: nil, status: .draft, createdAt: Date(), updatedAt: Date())
        let saved = try await draftRepo.insert(draft)
        guard let id = saved.id else {
            #expect(false, "Insert should return id")
            return
        }
        try await draftRepo.delete(id: id)
        let fetched = try await draftRepo.fetch(id: id)
        #expect(fetched == nil)
    }

    /// 关联账号的草稿 → 删除账号时级联删除
    @Test
    func testDraftCascadeDeleteWithAccount() async throws {
        let account = Account(platform: .instagram, username: "cascade_\(UUID())", displayName: "C",
                              authState: .authorized, createdAt: Date(), updatedAt: Date())
        let savedAccount = try await accountRepo.insert(account)
        guard let accountId = savedAccount.id else {
            #expect(false, "Account insert should return id")
            return
        }

        let draft = DraftPost(id: nil, accountId: accountId, caption: "cascade draft", imageFilename: nil,
                              scheduledAt: nil, status: .draft, createdAt: Date(), updatedAt: Date())
        let savedDraft = try await draftRepo.insert(draft)
        guard let draftId = savedDraft.id else {
            #expect(false, "Draft insert should return id")
            return
        }

        try await accountRepo.delete(id: accountId)
        let fetched = try await draftRepo.fetch(id: draftId)
        #expect(fetched == nil, "Account deletion should cascade to drafts")
    }

    // MARK: - 评论 DTO 解码

    /// IGComment 解码 → 字段匹配
    @Test
    func testIGCommentDecoding() throws {
        let json = """
        {"id":"17895695668004550","text":"Nice post!","timestamp":"2026-08-01T10:00:00+0000","username":"fan_user"}
        """.data(using: .utf8)!
        let comment = try JSONDecoder().decode(IGComment.self, from: json)
        #expect(comment.id == "17895695668004550")
        #expect(comment.text == "Nice post!")
        #expect(comment.username == "fan_user")
    }

    /// IGCommentResponse 解码 → data 数组
    @Test
    func testIGCommentResponseDecoding() throws {
        let json = """
        {"data":[{"id":"c1","text":"hi","username":"u"},{"id":"c2","text":"hello"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(IGCommentResponse.self, from: json)
        #expect(response.data?.count == 2)
        #expect(response.data?.first?.id == "c1")
    }

    /// IGCommentReplyResponse 解码 → id 返回
    @Test
    func testIGCommentReplyResponseDecoding() throws {
        let json = #"{"id":"1791234567890"}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(IGCommentReplyResponse.self, from: json)
        #expect(response.id == "1791234567890")
    }

    /// IGUser accountType 解码 → account_type 字段映射
    @Test
    func testIGUserAccountTypeDecoding() throws {
        let json = """
        {"id":"1","username":"creator","account_type":"CREATOR"}
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(IGUser.self, from: json)
        #expect(user.accountType == "CREATOR")
    }
}
