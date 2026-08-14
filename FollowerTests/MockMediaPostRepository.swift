//
//  MockMediaPostRepository.swift
//  FollowerTests
//
//  内存版 MediaPostRepository — 避免测试触碰共享数据库，
//  让「最佳发帖时间」等依赖帖子数据的流程可注入确定性样本。
//

import Foundation
@testable import Follower

/// 内存版 MediaPostRepository：测试用，可预设/读取帖子列表
final class MockMediaPostRepository: MediaPostRepositoryProtocol, @unchecked Sendable {
    /// 预设帖子（fetchRecent 按 limit 截断返回）
    var posts: [MediaPost] = []

    func upsertBatch(accountId: Int64, media: [MediaPost]) async throws -> [MediaPost] {
        posts = media
        return media
    }

    func fetchRecent(accountId: Int64, limit: Int) async throws -> [MediaPost] {
        Array(posts.prefix(limit))
    }

    func fetchAll(accountId: Int64) async throws -> [MediaPost] {
        posts
    }
}
