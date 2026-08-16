//
//  CommentDMViewModel.swift
//  Follower
//
//  评论→私信 ViewModel — 规则管理 + 防重 + 限流 + 执行流程。
//  - 规则配置持久化（UserDefaults）
//  - 防重：已回复评论 id 记录（同评论不重复触发）
//  - 限流：750 条/小时/帖滚动计数（超限跳过并记录）
//  - 执行：拉评论 → 匹配规则 → 24h 窗口校验 → 防重 → 限流 → 发送
//

import Foundation

@MainActor
@Observable
final class CommentDMViewModel {

    /// 评论私密回复 API
    private let apiClient: InstagramAPIClientProtocol
    private let tokenProvider: TokenProviderProtocol
    private let accountId: Int64?
    private let mediaID: String

    // MARK: - 状态

    /// 是否有可用的帖子（mediaID 非空）
    var hasMedia: Bool { !mediaID.isEmpty }

    /// 触发规则（持久化）
    var rules: [DMTriggerRule] = []
    /// 最近一次执行统计
    var lastResult: CommentDMResultSummary?
    /// 正在执行
    var isRunning = false
    /// 已发送总数（本轮会话）
    var sentCount = 0

    private let rulesKey: String
    private let repliedKey: String
    private let rateKey: String
    private var repliedSet: Set<String> = []
    /// 限流：小时桶 → 发送数（滚动窗口）
    private var rateBuckets: [Int: Int] = [:]
    private var hourlyResetDate: Date = Date()

    // MARK: - 结果

    struct CommentDMResultSummary: Sendable {
        let scanned: Int
        let matched: Int
        let sent: Int
        let skippedDuplicate: Int
        let skippedWindow: Int
        let rateLimited: Int
    }

    init(apiClient: InstagramAPIClientProtocol,
         tokenProvider: TokenProviderProtocol,
         accountId: Int64?,
         mediaID: String) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
        self.accountId = accountId
        self.mediaID = mediaID
        self.rulesKey = "commentDMRules-\(mediaID)"
        self.repliedKey = "commentDMReplied-\(mediaID)"
        self.rateKey = "commentDMRate-\(mediaID)"
        loadState()
    }

    // MARK: - 规则管理

    func addRule(keyword: String, template: String) {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty, !template.isEmpty else { return }
        rules.append(DMTriggerRule(keyword: kw, messageTemplate: template, isEnabled: true))
        persistRules()
    }

    func removeRule(_ rule: DMTriggerRule) {
        rules.removeAll { $0.id == rule.id }
        persistRules()
    }

    func toggleRule(_ rule: DMTriggerRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx].isEnabled.toggle()
            persistRules()
        }
    }

    /// 重置防重记录（允许重新触发历史评论）
    func resetRepliedHistory() {
        repliedSet = []
        UserDefaults.standard.removeObject(forKey: repliedKey)
    }

    // MARK: - 执行流程

    /// 轮询评论并触发私密回复
    func run() async {
        guard !isRunning, !rules.isEmpty, let accountId else { return }
        isRunning = true
        defer { isRunning = false }

        var scanned = 0, matched = 0, sent = 0, dup = 0, window = 0, limited = 0
        let enabledRules = rules.filter(\.isEnabled)
        var rng = SeededRandom(seed: 42)

        do {
            let token = try await tokenProvider.getToken(accountId: accountId)
            let comments = try await apiClient.fetchComments(
                accessToken: token, mediaID: mediaID, limit: 50)
            scanned = comments.count

            for comment in comments {
                // 1. 防重
                guard !repliedSet.contains(comment.id) else { dup += 1; continue }
                // 2. 匹配规则
                guard let rule = CommentDMService.match(text: comment.text ?? "", rules: enabledRules) else { continue }
                matched += 1
                // 3. 24h 窗口
                guard CommentDMService.isWithinWindow(commentTimestamp: comment.timestamp) else {
                    window += 1
                    continue
                }
                // 4. 限流
                guard canSend() else { limited += 1; continue }
                // 5. 发送
                let message = CommentDMService.render(
                    template: rule.messageTemplate, username: comment.username, rng: &rng)
                if (try? await apiClient.fetchCommentPrivateReply(
                    accessToken: token, commentID: comment.id, message: message)) != nil {
                    sent += 1
                    sentCount += 1
                    markReplied(comment.id)
                }
            }
        } catch {
            // 网络/权限错误：保持状态，等待下次轮询
        }

        lastResult = CommentDMResultSummary(
            scanned: scanned, matched: matched, sent: sent,
            skippedDuplicate: dup, skippedWindow: window, rateLimited: limited)
    }

    // MARK: - 限流 / 防重（确定性）

    /// 限流判断：单帖 750 条/小时（滚动小时桶）
    private func canSend() -> Bool {
        let now = Date()
        if now.timeIntervalSince(hourlyResetDate) >= 3600 {
            rateBuckets = [:]
            hourlyResetDate = now
        }
        let hourKey = Int(now.timeIntervalSince1970 / 3600)
        let count = rateBuckets[hourKey] ?? 0
        guard count < CommentDMService.hourlyReplyLimit else { return false }
        rateBuckets[hourKey] = count + 1
        persistRate()
        return true
    }

    private func markReplied(_ commentID: String) {
        repliedSet.insert(commentID)
        persistReplied()
    }

    // MARK: - 持久化

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let saved = try? JSONDecoder().decode([DMTriggerRule].self, from: data) {
            rules = saved
        }
        if let saved = UserDefaults.standard.stringArray(forKey: repliedKey) {
            repliedSet = Set(saved)
        }
        if let saved = UserDefaults.standard.dictionary(forKey: rateKey) as? [String: Int] {
            rateBuckets = Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        }
    }

    private func persistRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    private func persistReplied() {
        UserDefaults.standard.set(Array(repliedSet), forKey: repliedKey)
    }

    private func persistRate() {
        UserDefaults.standard.set(
            Dictionary(uniqueKeysWithValues: rateBuckets.map { (String($0.key), $0.value) }),
            forKey: rateKey)
    }
}
