//
//  CommentService.swift
//  Follower
//
//  评论管理服务 — 拉取 / 回复 / 删除 Instagram 评论。
//  依赖 InstagramAPIClient（Business API 端点）+ TokenProvider。
//  注意：评论端点仅对 BUSINESS / CREATOR 账号开放。
//

import Foundation

// MARK: - CommentServiceProtocol

/// 评论管理数据协议
protocol CommentServiceProtocol: Sendable {
    /// 拉取某帖子的评论列表
    func fetchComments(accountId: Int64, mediaID: String) async throws -> [IGComment]
    /// 回复某帖子的评论（作为一级评论发布），返回新评论 id
    func reply(accountId: Int64, mediaID: String, message: String) async throws -> String
    /// 删除评论
    func delete(accountId: Int64, commentID: String) async throws
}

// MARK: - CommentService

/// 评论管理服务实现 — 组合 apiResolver + tokenProvider，按 accountId 取 token 后分派 client
final class CommentService: CommentServiceProtocol {
    private let apiResolver: APIClientResolver
    private let tokenProvider: TokenProviderProtocol

    init(apiResolver: APIClientResolver, tokenProvider: TokenProviderProtocol) {
        self.apiResolver = apiResolver
        self.tokenProvider = tokenProvider
    }

    func fetchComments(accountId: Int64, mediaID: String) async throws -> [IGComment] {
        let token = try await tokenProvider.getToken(accountId: accountId)
        let client = apiResolver.client(for: token)
        return try await client.fetchComments(accessToken: token, mediaID: mediaID, limit: 50)
    }

    func reply(accountId: Int64, mediaID: String, message: String) async throws -> String {
        let token = try await tokenProvider.getToken(accountId: accountId)
        let client = apiResolver.client(for: token)
        return try await client.replyComment(accessToken: token, mediaID: mediaID, message: message)
    }

    func delete(accountId: Int64, commentID: String) async throws {
        let token = try await tokenProvider.getToken(accountId: accountId)
        let client = apiResolver.client(for: token)
        try await client.deleteComment(accessToken: token, commentID: commentID)
    }
}
