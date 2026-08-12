//
//  MockDraftPostRepository.swift
//  FollowerTests
//
//  内存实现 DraftPostRepositoryProtocol — 供 PostQueueViewModel /
//  PostComposerViewModel 测试注入：记录调用次数、支持注入失败行为、
//  插入自动分配递增 ID。
//

import Foundation
@testable import Follower

/// 内存草稿仓库 — 测试专用（真实仓库为 GRDB，行为已在 DraftPostTests 覆盖）
final class MockDraftPostRepository: DraftPostRepositoryProtocol {
    /// 内存草稿存储（按插入顺序）
    var drafts: [DraftPost] = []
    /// 非 nil 时所有操作抛错 — 模拟仓库故障
    var failureError: Error?
    /// 调用计数器
    var deleteCallCount = 0
    var updateCallCount = 0
    private var nextID: Int64 = 1

    func fetchAll() async throws -> [DraftPost] {
        try throwIfFailed()
        return drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetch(id: Int64) async throws -> DraftPost? {
        try throwIfFailed()
        return drafts.first { $0.id == id }
    }

    func fetch(status: DraftPostStatus) async throws -> [DraftPost] {
        try throwIfFailed()
        return drafts.filter { $0.status == status }
    }

    func insert(_ draft: DraftPost) async throws -> DraftPost {
        try throwIfFailed()
        var saved = draft
        saved.id = nextID
        nextID += 1
        drafts.append(saved)
        return saved
    }

    func update(_ draft: DraftPost) async throws {
        try throwIfFailed()
        updateCallCount += 1
        if let idx = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[idx] = draft
        }
    }

    func delete(id: Int64) async throws {
        try throwIfFailed()
        deleteCallCount += 1
        drafts.removeAll { $0.id == id }
    }

    func count() async throws -> Int {
        try throwIfFailed()
        return drafts.count
    }

    /// 注入故障：所有操作抛错
    func fail(with error: Error) {
        failureError = error
    }

    /// 撤销故障注入
    func clearFailure() {
        failureError = nil
    }

    private func throwIfFailed() throws {
        if let failureError { throw failureError }
    }
}
