//
//  ContentAttributionService.swift
//  Follower
//
//  Premium: 内容→增长归因（Phi+）— 回答"什么内容真正涨了粉"。
//
//  算法（确定性、可测）：
//  1. 每篇帖子 p 的归因窗口 = [发帖日, 发帖日+6]（7 天）
//  2. 窗口涨粉 Δ_p = F(窗口末) − F(发帖日前一日)（快照最近可用值；Δ ≤ 0 不计）
//  3. 互动加权分摊：窗口内多篇帖子时，Δ_p 按各帖互动（likes+comments）占比分配
//  4. 每帖最终归因 a_p 只由自身窗口计算一次（不跨窗口累计，避免重复计数）
//  5. 聚合：类型 × 星期 贡献矩阵 + Top 贡献帖子
//
//  语义说明：归因是相关性（发布 7 天窗口内的涨粉），非因果；UI 需注明"估算"。

import Foundation

// MARK: - 结果模型

/// 单维度贡献（类型 / 星期）
struct AttributionContribution: Sendable {
    /// 归因涨粉
    let followerGain: Double
    /// 占总归因涨粉比例（0-1）
    let share: Double
}

/// 单帖归因结果
struct AttributedPost: Sendable {
    let type: ContentType
    let date: Date
    let caption: String
    let engagement: Int
    /// 归因涨粉
    let attributedFollowers: Double
}

/// 内容归因结果
struct ContentAttributionResult: Sendable {
    /// 归因总涨粉（有帖子覆盖且正增长的窗口合计）
    let totalAttributedGain: Double
    /// 类型贡献（按贡献降序）
    let typeContribution: [(type: ContentType, contribution: AttributionContribution)]
    /// 星期贡献（1=周日...7=周六，按贡献降序）
    let weekdayContribution: [(weekday: Int, contribution: AttributionContribution)]
    /// 贡献最大类型
    let bestType: ContentType?
    /// 贡献最大星期（1=周日...7=周六）
    let bestWeekday: Int?
    /// Top 贡献帖子（归因降序）
    let topPosts: [AttributedPost]
    /// 参与归因的帖子数
    let attributedPosts: Int
}

// MARK: - Service

/// 内容归因服务 — 确定性纯计算，零 API 依赖
final class ContentAttributionService: Sendable {

    /// 归因窗口（天）：发帖后 N 天的涨粉计入该帖
    static let attributionWindowDays = 7
    /// 冷启动：帖子 < 5 或快照 < 2 → nil
    static let minPosts = 5

    /// 冷启动（帖子不足 / 快照不足）→ nil（调用方显示空态）
    func analyze(posts: [MediaPost], snapshots: [Snapshot]) async -> ContentAttributionResult? {
        guard posts.count >= Self.minPosts else { return nil }
        let sortedSnaps = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard sortedSnaps.count >= 2 else { return nil }

        let cal = Calendar.current
        let windowDays = Self.attributionWindowDays

        // 快照查找：某日（含）之前最近的快照 / 之后最近快照
        func followersBefore(_ date: Date) -> Double? {
            let day = cal.startOfDay(for: date)
            return sortedSnaps.last { $0.observedAt <= day }.map { Double($0.followersCount) }
        }
        func followersAfter(_ date: Date) -> Double? {
            let day = cal.startOfDay(for: date)
            return sortedSnaps.first { $0.observedAt >= day }.map { Double($0.followersCount) }
        }

        // 1. 每帖窗口涨粉（Δ > 0 才计入归因）
        struct WindowDelta { let post: MediaPost; let delta: Double }
        var deltas: [WindowDelta] = []
        var postsByDay: [Date: [MediaPost]] = [:]
        for post in posts {
            let day = cal.startOfDay(for: post.date)
            postsByDay[day, default: []].append(post)
        }
        for post in posts {
            let day = cal.startOfDay(for: post.date)
            let before = day.addingTimeInterval(-86400)
            let after = day.addingTimeInterval(Double(windowDays) * 86400)
            guard let startF = followersBefore(before), let endF = followersAfter(after) else { continue }
            let delta = endF - startF
            guard delta > 0 else { continue }
            deltas.append(WindowDelta(post: post, delta: delta))
        }

        // 2. 互动加权分摊：窗口内多帖共享窗口增量
        var attributed: [String: (post: MediaPost, gain: Double)] = [:]  // igMediaID → 归因
        for item in deltas {
            let day = cal.startOfDay(for: item.post.date)
            let windowEnd = day.addingTimeInterval(Double(windowDays) * 86400)
            // 窗口内帖子集：发帖日在 [day, day+6]
            let inWindow = posts.filter {
                let d = cal.startOfDay(for: $0.date)
                return d >= day && d <= windowEnd
            }
            let totalEng = inWindow.reduce(0) { $0 + $1.likes + $1.comments }
            let eng = item.post.likes + item.post.comments
            let share = totalEng > 0 ? Double(eng) / Double(totalEng) : 0
            let gain = item.delta * share
            var cur = attributed[item.post.igMediaID] ?? (item.post, 0)
            cur.gain += gain
            attributed[item.post.igMediaID] = cur
        }

        guard !attributed.isEmpty else { return nil }

        // 3. 聚合：类型 / 星期
        var typeGain: [ContentType: Double] = [:]
        var weekdayGain: [Int: Double] = [:]
        for (_, item) in attributed {
            if let type = ContentType(mediaType: item.post.type) {
                typeGain[type, default: 0] += item.gain
            }
            let wd = cal.component(.weekday, from: item.post.date)
            weekdayGain[wd, default: 0] += item.gain
        }
        let total = attributed.values.reduce(0) { $0 + $1.gain }

        let typeContribution = typeGain
            .map { type, gain in
                (type, AttributionContribution(followerGain: gain, share: total > 0 ? gain / total : 0))
            }
            .sorted { $0.1.followerGain > $1.1.followerGain }
        let weekdayContribution = weekdayGain
            .map { wd, gain in
                (wd, AttributionContribution(followerGain: gain, share: total > 0 ? gain / total : 0))
            }
            .sorted { $0.1.followerGain > $1.1.followerGain }

        // 4. Top 帖子
        let topPosts = attributed.values
            .sorted { $0.gain > $1.gain }
            .prefix(5)
            .map { item in
                AttributedPost(
                    type: ContentType(mediaType: item.post.type) ?? .photo,
                    date: item.post.date,
                    caption: item.post.caption,
                    engagement: item.post.likes + item.post.comments,
                    attributedFollowers: item.gain
                )
            }

        return ContentAttributionResult(
            totalAttributedGain: total,
            typeContribution: typeContribution,
            weekdayContribution: weekdayContribution,
            bestType: typeContribution.first?.0,
            bestWeekday: weekdayContribution.first?.0,
            topPosts: Array(topPosts),
            attributedPosts: attributed.count
        )
    }
}
