//
//  CommentViewModel.swift
//  Follower
//
//  评论管理 ViewModel — 拉取 / 回复 / 删除帖子评论。
//  仅对 BUSINESS / CREATOR 账号可用（Business API 端点）。
//

import Foundation

@MainActor
@Observable
final class CommentViewModel {

    private let commentService: CommentServiceProtocol

    var comments: [IGComment] = []
    var isLoading: Bool = false
    var isReplying: Bool = false
    var replyText: String = ""
    var errorMessage: String?

    init(commentService: CommentServiceProtocol) {
        self.commentService = commentService
    }

    /// 拉取帖子评论
    func load(accountId: Int64, mediaID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await commentService.fetchComments(accountId: accountId, mediaID: mediaID)
            errorMessage = nil
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    /// 回复评论（作为一级评论发布），成功后追加到列表
    func reply(accountId: Int64, mediaID: String) async {
        let message = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        isReplying = true
        defer { isReplying = false }
        do {
            let newID = try await commentService.reply(accountId: accountId, mediaID: mediaID, message: message)
            if !newID.isEmpty {
                comments.insert(
                    IGComment(id: newID, text: message, timestamp: ISO8601DateFormatter().string(from: Date()), username: nil),
                    at: 0
                )
            }
            replyText = ""
            errorMessage = nil
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    /// 删除评论，成功后从列表移除
    func delete(accountId: Int64, comment: IGComment) async {
        do {
            try await commentService.delete(accountId: accountId, commentID: comment.id)
            comments.removeAll { $0.id == comment.id }
            errorMessage = nil
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    // MARK: - Private

    /// 把 API 错误转成用户可读文案（含商务账号提示）
    private static func friendlyError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "Token 无效或已过期，请重新连接账号"
            case .httpError(let code, let body):
                // 个人账号 / 权限不足常见于 400 且 body 含 "permission"
                if code == 400, let body, body.contains("permission") {
                    return "需要 Instagram 商务（Business/Creator）账号才能管理评论"
                }
                return "请求失败（HTTP \(code)）"
            default:
                return apiError.errorDescription ?? "请求失败"
            }
        }
        return error.localizedDescription
    }
}
