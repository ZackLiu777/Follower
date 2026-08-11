//
//  PostQueueViewModelTests.swift
//  FollowerTests
//
//  发布队列 ViewModel 单元测试 — 加载成功/失败、删除（清理+刷新）、
//  状态流转（已发布 / 发布失败）。仓库用 MockDraftPostRepository 注入。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for PostQueueViewModel — load, delete, status transitions
@MainActor
struct PostQueueViewModelTests {

    /// 构造草稿（caption 唯一化避免用例间混淆）
    private func makeDraft(caption: String = "draft_\(UUID())", status: DraftPostStatus = .draft) -> DraftPost {
        DraftPost(
            id: nil, accountId: nil, caption: caption, imageFilename: nil,
            scheduledAt: nil, status: status, createdAt: Date(), updatedAt: Date()
        )
    }

    /// 加载成功 → drafts 按更新时间倒序填充
    @Test
    func testLoadPopulatesDrafts() async {
        let repo = MockDraftPostRepository()
        let older = makeDraft(caption: "older")
        let newer = makeDraft(caption: "newer")
        _ = try? await repo.insert(older)
        _ = try? await repo.insert(newer)

        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.load()

        #expect(vm.drafts.count == 2)
        #expect(vm.errorMessage == nil)
    }

    /// 加载失败 → errorMessage 非 nil，drafts 保持空
    @Test
    func testLoadFailureSetsErrorMessage() async {
        let repo = MockDraftPostRepository()
        repo.fail(with: NSError(domain: "test", code: 1))

        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.load()

        #expect(vm.errorMessage != nil)
        #expect(vm.drafts.isEmpty)
    }

    /// 删除草稿 → repo.delete 被调用 + 列表刷新
    @Test
    func testDeleteRemovesDraftAndReloads() async {
        let repo = MockDraftPostRepository()
        let draft = try! await repo.insert(makeDraft(caption: "to_delete"))
        let keep = try! await repo.insert(makeDraft(caption: "keep"))

        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.delete(draft)

        #expect(repo.deleteCallCount == 1)
        #expect(vm.drafts.contains { $0.id == keep.id })
        #expect(!vm.drafts.contains { $0.id == draft.id })
    }

    /// 删除无 id 的草稿 → 不崩溃（跳过仓库删除）
    @Test
    func testDeleteDraftWithoutIDIsSafe() async {
        let repo = MockDraftPostRepository()
        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.delete(makeDraft(caption: "no_id"))
        #expect(repo.deleteCallCount == 0)
    }

    /// 标记已发布 → 仓库中状态流转为 published
    @Test
    func testMarkPublishedTransitionsStatus() async {
        let repo = MockDraftPostRepository()
        let draft = try! await repo.insert(makeDraft(caption: "pub"))

        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.markPublished(draft)

        let fetched = try? await repo.fetch(id: draft.id!)
        #expect(fetched?.status == .published)
        #expect(repo.updateCallCount >= 1)
    }

    /// 标记失败 → 仓库中状态流转为 failed
    @Test
    func testMarkFailedTransitionsStatus() async {
        let repo = MockDraftPostRepository()
        let draft = try! await repo.insert(makeDraft(caption: "fail"))

        let vm = PostQueueViewModel(draftRepo: repo, assistant: PostAssistantService())
        await vm.markFailed(draft)

        let fetched = try? await repo.fetch(id: draft.id!)
        #expect(fetched?.status == .failed)
    }
}
