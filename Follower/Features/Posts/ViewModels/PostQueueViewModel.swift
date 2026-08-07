//
//  PostQueueViewModel.swift
//  Follower
//
//  发布队列 ViewModel — 草稿列表加载 / 删除 / 状态流转。
//

import Foundation

@MainActor
@Observable
final class PostQueueViewModel {

    private let draftRepo: DraftPostRepositoryProtocol
    private let assistant: PostAssistantService

    var drafts: [DraftPost] = []
    var isLoading: Bool = false
    var errorMessage: String?

    init(draftRepo: DraftPostRepositoryProtocol, assistant: PostAssistantService) {
        self.draftRepo = draftRepo
        self.assistant = assistant
    }

    /// 加载全部草稿（按更新时间倒序）
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            drafts = try await draftRepo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除草稿：清理图片文件 + 取消排期提醒
    func delete(_ draft: DraftPost) async {
        if let id = draft.id {
            try? await draftRepo.delete(id: id)
            await assistant.cancelReminder(draftID: id)
        }
        assistant.deleteImage(filename: draft.imageFilename)
        await load()
    }

    /// 标记为已发布（用户在 Instagram 确认完成后手动标记）
    func markPublished(_ draft: DraftPost) async {
        guard var updated = try? await fetch(id: draft.id) ?? draft else { return }
        updated.status = .published
        updated.updatedAt = Date()
        if let id = updated.id {
            try? await draftRepo.update(updated)
            await assistant.cancelReminder(draftID: id)
        }
        await load()
    }

    /// 标记为发布失败 / 取消
    func markFailed(_ draft: DraftPost) async {
        guard var updated = try? await fetch(id: draft.id) ?? draft else { return }
        updated.status = .failed
        updated.updatedAt = Date()
        if let id = updated.id {
            try? await draftRepo.update(updated)
            await assistant.cancelReminder(draftID: id)
        }
        await load()
    }

    // MARK: - Private

    private func fetch(id: Int64?) async throws -> DraftPost? {
        guard let id else { return nil }
        return try await draftRepo.fetch(id: id)
    }
}
