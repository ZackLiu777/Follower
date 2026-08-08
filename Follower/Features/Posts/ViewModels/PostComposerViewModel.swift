//
//  PostComposerViewModel.swift
//  Follower
//
//  发布助手 ViewModel — 草稿 / 排期 / 立即发布 三种流程的状态编排。
//  发布动作交给系统分享面板 + 剪贴板，App 只负责内容准备与记录。
//

import Foundation

@MainActor
@Observable
final class PostComposerViewModel {

    private let draftRepo: DraftPostRepositoryProtocol
    private let assistant: PostAssistantService

    // MARK: - 编辑状态

    var caption: String = ""
    /// 新选图片数据（未保存到沙盒前）
    var pendingImageData: Data?
    /// 已保存草稿的图片文件名（编辑已有草稿时非 nil）
    var existingImageFilename: String?
    var scheduledAt: Date = Date().addingTimeInterval(3600)
    var isScheduled: Bool = false
    var errorMessage: String?
    /// 保存成功后置 true（View 据此关闭）
    var didFinish: Bool = false
    /// 立即发布流程中要分享的图片文件 URL
    var shareURL: URL?
    /// 正在编辑的草稿（nil = 新建）
    var editingDraft: DraftPost?

    init(draftRepo: DraftPostRepositoryProtocol, assistant: PostAssistantService) {
        self.draftRepo = draftRepo
        self.assistant = assistant
    }

    /// 从已有草稿装载编辑状态
    func load(_ draft: DraftPost) {
        editingDraft = draft
        caption = draft.caption
        existingImageFilename = draft.imageFilename
        isScheduled = draft.status == .scheduled
        if let at = draft.scheduledAt { scheduledAt = at }
    }

    var hasImage: Bool {
        pendingImageData != nil || existingImageFilename != nil
    }

    // MARK: - 保存草稿

    /// 保存为草稿（不排期），返回保存结果
    func saveDraft() async -> DraftPost? {
        await persist(status: .draft, scheduledAt: nil)
    }

    /// 排期发布：保存为 scheduled + 调度本地提醒
    func scheduleDraft() async -> DraftPost? {
        guard let draft = await persist(status: .scheduled, scheduledAt: scheduledAt) else {
            return nil
        }
        await assistant.scheduleReminder(draftID: draft.id ?? -1, caption: draft.caption, at: scheduledAt)
        didFinish = true
        return draft
    }

    // MARK: - 立即发布

    /// 立即发布准备：保存图片 → 复制文案 → 返回待分享的图片文件 URL
    func prepareForImmediatePublish() async -> URL? {
        do {
            // 先保存图片（新选图片写入沙盒）
            if let data = pendingImageData {
                existingImageFilename = try assistant.saveImageData(data)
                pendingImageData = nil
            }
            // 没图无法发布（Instagram 发布必须带图）
            guard let filename = existingImageFilename,
                  let url = assistant.draftFileURL(filename: filename) else {
                errorMessage = "请先选择一张图片"
                return nil
            }
            assistant.copyCaption(caption)
            shareURL = url
            return url
        } catch {
            errorMessage = "图片保存失败：\(error.localizedDescription)"
            return nil
        }
    }

    /// 分享面板完成后调用：completed 为 true → 记录为已发布；否则保留为草稿（可重试）
    func finishPublishFlow(completed: Bool) async {
        if completed {
            let draft = DraftPost(
                id: editingDraft?.id,
                accountId: editingDraft?.accountId,
                caption: caption,
                imageFilename: existingImageFilename,
                scheduledAt: editingDraft?.scheduledAt,
                status: .published,
                createdAt: Date(),
                updatedAt: Date()
            )
            if let id = draft.id {
                try? await draftRepo.update(draft)
                await assistant.cancelReminder(draftID: id)
            } else {
                _ = try? await draftRepo.insert(draft)
            }
        } else if editingDraft == nil, let filename = existingImageFilename {
            // 用户取消分享：保留为草稿，可稍后从队列重试
            _ = try? await draftRepo.insert(DraftPost(
                id: nil,
                accountId: nil,
                caption: caption,
                imageFilename: filename,
                scheduledAt: nil,
                status: .draft,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
        didFinish = true
    }

    // MARK: - Private

    /// 统一持久化：新建 / 更新草稿
    private func persist(status: DraftPostStatus, scheduledAt: Date?) async -> DraftPost? {
        do {
            // 新选图片先落盘
            if let data = pendingImageData {
                existingImageFilename = try assistant.saveImageData(data)
                pendingImageData = nil
            }
            let draft = DraftPost(
                id: editingDraft?.id,
                accountId: editingDraft?.accountId,
                caption: caption,
                imageFilename: existingImageFilename,
                scheduledAt: scheduledAt,
                status: status,
                createdAt: Date(),
                updatedAt: Date()
            )
            if let id = draft.id {
                try await draftRepo.update(draft)
            } else {
                let inserted = try await draftRepo.insert(draft)
                editingDraft = inserted
            }
            didFinish = true
            return draft
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            return nil
        }
    }
}
