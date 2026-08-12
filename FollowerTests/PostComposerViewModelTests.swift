//
//  PostComposerViewModelTests.swift
//  FollowerTests
//
//  发布助手 ViewModel 单元测试 — 保存草稿、排期发布、立即发布
//  （无图报错 / 有图分享 URL）、发布流程完成回调、草稿装载。
//  仓库用 MockDraftPostRepository 注入；图片走真实沙盒文件。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for PostComposerViewModel — save, schedule, immediate publish, finish flow
@MainActor
struct PostComposerViewModelTests {

    /// 新建草稿（无图）→ 仓库插入 status=.draft，didFinish 置位
    @Test
    func testSaveDraftInsertsDraft() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        vm.caption = "测试文案"

        let saved = await vm.saveDraft()

        #expect(saved != nil)
        #expect(saved?.status == .draft)
        #expect(vm.didFinish)
        #expect(repo.drafts.count == 1)
        // editingDraft 回填为插入后的草稿
        #expect(vm.editingDraft?.id != nil)
    }

    /// 排期发布 → 状态 .scheduled + 记录 scheduledAt，didFinish 置位
    @Test
    func testScheduleDraftInsertsScheduled() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        vm.caption = "排期文案"
        vm.isScheduled = true
        let target = Date().addingTimeInterval(7200)
        vm.scheduledAt = target

        let saved = await vm.scheduleDraft()

        #expect(saved?.status == .scheduled)
        #expect(vm.didFinish)
        let fetched = repo.drafts.first
        #expect(fetched?.scheduledAt != nil)
        #expect(abs((fetched?.scheduledAt?.timeIntervalSince(target) ?? 0)) < 60)
    }

    /// 立即发布无图 → 返回 nil + 错误提示（Instagram 发布必须带图）
    @Test
    func testPrepareImmediatePublishWithoutImageFails() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())

        let url = await vm.prepareForImmediatePublish()

        #expect(url == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.shareURL == nil)
    }

    /// 立即发布有图 → 图片落盘，返回可分享 URL，shareURL 置位
    @Test
    func testPrepareImmediatePublishWithImageSucceeds() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        vm.pendingImageData = Data([0xFF, 0xD8, 0xFF, 1, 2, 3])

        let url = await vm.prepareForImmediatePublish()

        #expect(url != nil)
        #expect(vm.shareURL != nil)
        #expect(vm.errorMessage == nil)
        // 图片已从 pending 转移到持久化文件名
        #expect(vm.pendingImageData == nil)
        #expect(vm.existingImageFilename != nil)
    }

    /// 发布流程完成（completed=true）→ 记录为已发布
    @Test
    func testFinishPublishFlowCompletedInsertsPublished() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        vm.caption = "发布文案"
        vm.existingImageFilename = "photo.jpg"

        await vm.finishPublishFlow(completed: true)

        #expect(vm.didFinish)
        #expect(repo.drafts.count == 1)
        #expect(repo.drafts.first?.status == .published)
    }

    /// 发布流程取消（completed=false）且为新草稿 → 保留为 .draft（可重试）
    @Test
    func testFinishPublishFlowCancelledKeepsDraft() async {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        vm.caption = "待重试文案"
        vm.existingImageFilename = "photo.jpg"

        await vm.finishPublishFlow(completed: false)

        #expect(repo.drafts.count == 1)
        #expect(repo.drafts.first?.status == .draft)
        #expect(vm.didFinish)
    }

    /// 装载已有草稿 → 编辑状态回填（caption / 图片 / 排期标志）
    @Test
    func testLoadPopulatesEditState() {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        let scheduledAt = Date().addingTimeInterval(3600)
        let draft = DraftPost(
            id: 99, accountId: 3, caption: "旧文案", imageFilename: "old.jpg",
            scheduledAt: scheduledAt, status: .scheduled, createdAt: Date(), updatedAt: Date()
        )

        vm.load(draft)

        #expect(vm.editingDraft?.id == 99)
        #expect(vm.caption == "旧文案")
        #expect(vm.existingImageFilename == "old.jpg")
        #expect(vm.isScheduled)
        #expect(abs(vm.scheduledAt.timeIntervalSince(scheduledAt)) < 60)
    }

    /// hasImage：新选图或已有图任一存在
    @Test
    func testHasImage() {
        let repo = MockDraftPostRepository()
        let vm = PostComposerViewModel(draftRepo: repo, assistant: PostAssistantService())
        #expect(!vm.hasImage)

        vm.pendingImageData = Data([1])
        #expect(vm.hasImage)

        vm.pendingImageData = nil
        vm.existingImageFilename = "x.jpg"
        #expect(vm.hasImage)
    }
}
