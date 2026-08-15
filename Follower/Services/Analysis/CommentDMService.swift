//
//  CommentDMService.swift
//  Follower
//
//  Premium: 评论触发私信（Comment-to-DM）— 官方 Comment Private Reply 机制。
//  - 用户配置触发规则（关键词 → 私信文案模板）
//  - 轮询评论 → 匹配关键词 → 发送私密回复（POST /{comment-id}/private_replies）
//  - 纯函数核心（匹配 / 模板渲染 / 24h 窗口判断）确定性可测
//
//  合规红线（Meta）：
//  - 仅向评论者发私密回复（用户主动互动 → 24h 窗口内合法）
//  - 单帖评论私密回复上限 750 条/小时
//  - 动态文本变体：插入 @用户名 + 同义词池，避免完全一致的营销文案
//

import Foundation

// MARK: - DMTriggerRule

/// 触发规则：评论含关键词 → 发送模板私信
struct DMTriggerRule: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// 触发关键词（大小写不敏感，子串匹配）
    var keyword: String
    /// 私信文案模板（支持 {username} 占位）
    var messageTemplate: String
    /// 是否启用
    var isEnabled: Bool
}

// MARK: - CommentDMService

/// 评论→私信 纯函数核心
struct CommentDMService: Sendable {

    /// 单帖评论私密回复上限（Meta 官方限制：750 条/小时/帖）
    static let hourlyReplyLimit = 750
    /// 私信互动窗口（Meta 24h 规则；私密回复属于互动响应，本地双保险校验）
    static let interactionWindowHours = 24.0

    /// 匹配规则：评论文本包含任一启用规则的关键词（大小写不敏感）→ 返回该规则
    static func match(text: String, rules: [DMTriggerRule]) -> DMTriggerRule? {
        let lower = text.lowercased()
        return rules.first { rule in
            rule.isEnabled && !rule.keyword.isEmpty && lower.contains(rule.keyword.lowercased())
        }
    }

    /// 模板渲染：{username} 占位替换 + 动态变体（问候语同义词池，防完全一致文案）
    /// - Parameters:
    ///   - template: 文案模板
    ///   - username: 评论者用户名（可为 nil → 不插入占位）
    ///   - rng: 注入的确定性随机源（变体选择）
    static func render(template: String, username: String?, rng: inout SeededRandom) -> String {
        var message = template
        // 占位替换
        message = message.replacingOccurrences(
            of: "{username}", with: username.map { "@\($0)" } ?? "there")
        // 动态变体：随机插入一个问候语变体（如果模板没有问候语则前缀）
        let variants = ["Hi", "Hey", "Hello", "Hi there"]
        if !variants.contains(where: { message.lowercased().hasPrefix($0.lowercased() + " ") }) {
            message = "\(variants[rng.int(in: 0...(variants.count - 1))]) \(message)"
        }
        return message
    }

    /// 24h 互动窗口判断：评论时间戳在窗口内才可响应（ISO8601 解析失败 → false）
    static func isWithinWindow(commentTimestamp: String?) -> Bool {
        guard let raw = commentTimestamp else { return false }
        let iso = ISO8601DateFormatter()
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        fallback.locale = Locale(identifier: "en_US_POSIX")
        guard let date = iso.date(from: raw) ?? fallback.date(from: raw) else { return false }
        return Date().timeIntervalSince(date) < interactionWindowHours * 3600
    }
}
