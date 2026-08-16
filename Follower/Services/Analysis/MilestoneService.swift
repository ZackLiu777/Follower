//
//  MilestoneService.swift
//  Follower
//
//  Premium: 成长里程碑（Growth Milestones）— 把账号历史重构为事件叙事：
//  粉丝里程碑 / 爆帖 / 最佳单帖 / 掉粉事件 / 最佳一周。
//
//  定位（与现有功能差异）：
//  - vs 真实性评估：它输出健康"评分"；这里只陈列事实事件，不判定好坏
//  - vs 内容归因：它做增长来源"拆解"；这里是单点事件标记，无权重分配
//  - vs 趋势预测：它预测未来；这里只回顾过去
//
//  纯函数、确定性可测：同输入必同输出，无 API 依赖。

import Foundation

// MARK: - 事件类型

/// 里程碑事件类型
enum MilestoneKind: String, Sendable, CaseIterable {
    /// 粉丝数首次跨过整数里程碑（1K/5K/10K…）
    case followerMilestone
    /// 爆帖（互动 > 账号均值 × 阈值）
    case viralPost
    /// 全量互动最高的帖子
    case bestPost
    /// 掉粉事件（单日净增最负）
    case unfollowEvent
    /// 最佳一周（7 日滑动净增峰值）
    case boostWeek
}

// MARK: - 事件模型

/// 单个里程碑事件（结构化数据；标题/细节由 View 用 L10n 模板渲染）
struct MilestoneEvent: Sendable, Identifiable, Equatable {
    /// 稳定 id（kind + 日期），同一事件重复计算不漂移
    var id: String { "\(kind.rawValue)-\(Int(date.timeIntervalSince1970))-\(value)" }
    let kind: MilestoneKind
    let date: Date
    /// 主数值：里程碑目标粉丝数 / 互动数 / 掉粉数 / 周净增数
    let value: Int
    /// 次数值（可选）：如爆帖的互动数、最佳周覆盖天数
    let secondaryValue: Int
}

// MARK: - 结果模型

/// 成长里程碑结果
struct MilestoneResult: Sendable {
    /// 全部事件（日期升序）
    let events: [MilestoneEvent]
    /// 事件总数
    var totalEvents: Int { events.count }
    /// 最近一次事件
    var latest: MilestoneEvent? { events.last }
    /// 爆帖数量
    var viralCount: Int { events.filter { $0.kind == .viralPost }.count }
    /// 最佳单帖（互动最高的帖子；无帖子时 nil）
    let bestPost: MilestoneEvent?
}

// MARK: - Service

/// 成长里程碑服务 — 确定性纯计算
final class MilestoneService: Sendable {

    /// 粉丝里程碑目标值（升序）
    static let followerMilestones: [Int] = [1_000, 5_000, 10_000, 50_000, 100_000]
    /// 爆帖阈值：互动 > 账号均值 × 该倍数
    static let viralThreshold = 3.0
    /// 掉粉事件最多记录条数
    static let maxUnfollowEvents = 3
    /// 最佳一周窗口（天）
    static let boostWindowDays = 7

    /// 提取里程碑事件。posts 与 snapshots 均空 → nil（调用方显示空态）；
    /// 只有一方有数据时返回部分事件（不整体判 nil）。
    func extract(posts: [MediaPost], snapshots: [Snapshot]) async -> MilestoneResult? {
        let sortedPosts = posts.sorted { $0.date < $1.date }
        let sortedSnaps = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard !sortedPosts.isEmpty || !sortedSnaps.isEmpty else { return nil }

        var events: [MilestoneEvent] = []

        // ── 1. 粉丝里程碑：快照首次跨过目标值 ──
        if !sortedSnaps.isEmpty {
            var reached = Set<Int>()
            for snap in sortedSnaps {
                for target in Self.followerMilestones where !reached.contains(target) {
                    if snap.followersCount >= target {
                        reached.insert(target)
                        events.append(MilestoneEvent(
                            kind: .followerMilestone,
                            date: snap.observedAt,
                            value: target,
                            secondaryValue: snap.followersCount
                        ))
                    }
                }
            }
        }

        // ── 2. 爆帖 / 最佳单帖：互动显著超过账号均值 ──
        if !sortedPosts.isEmpty {
            let avgEng = sortedPosts.reduce(0) { $0 + $1.likes + $1.comments } / sortedPosts.count
            let maxPost = sortedPosts.max {
                $0.likes + $0.comments < $1.likes + $1.comments
            }

            if let maxPost {
                let maxEng = maxPost.likes + maxPost.comments
                events.append(MilestoneEvent(
                    kind: .bestPost,
                    date: maxPost.date,
                    value: maxEng,
                    secondaryValue: 0
                ))
            }

            if avgEng > 0 {
                let threshold = Double(avgEng) * Self.viralThreshold
                let viral = sortedPosts.filter {
                    Double($0.likes + $0.comments) > threshold
                }
                for post in viral {
                    events.append(MilestoneEvent(
                        kind: .viralPost,
                        date: post.date,
                        value: post.likes + post.comments,
                        secondaryValue: 0
                    ))
                }
            }
        }

        // ── 3. 掉粉事件：相邻快照日增量最负的 Top N ──
        if sortedSnaps.count >= 2 {
            var deltas: [(date: Date, drop: Int)] = []
            for i in 1..<sortedSnaps.count {
                let d = sortedSnaps[i].followersCount - sortedSnaps[i - 1].followersCount
                if d < 0 {
                    deltas.append((sortedSnaps[i].observedAt, -d))
                }
            }
            // 同一天多条快照去重：保留跌幅最大的
            let byDay = Dictionary(grouping: deltas, by: { Calendar.current.startOfDay(for: $0.date) })
            let worstPerDay = byDay.values.compactMap { group -> (Date, Int)? in
                guard let max = group.max(by: { $0.drop < $1.drop }) else { return nil }
                return (max.date, max.drop)
            }
            let topDrops = worstPerDay.sorted { $0.1 > $1.1 }.prefix(Self.maxUnfollowEvents)
            for item in topDrops {
                events.append(MilestoneEvent(
                    kind: .unfollowEvent,
                    date: item.0,
                    value: item.1,
                    secondaryValue: 0
                ))
            }
        }

        // ── 4. 最佳一周：7 日滑动净增峰值 ──
        if sortedSnaps.count >= 2 {
            let cal = Calendar.current
            // 日粒度净增（同天取最后一条快照）
            var netByDay: [Date: Int] = [:]
            for i in 1..<sortedSnaps.count {
                let d = cal.startOfDay(for: sortedSnaps[i].observedAt)
                netByDay[d] = sortedSnaps[i].followersCount - sortedSnaps[i - 1].followersCount
            }
            let days = netByDay.keys.sorted()
            if !days.isEmpty {
                var bestStart = days[0]
                var bestGain = Int.min
                for start in days {
                    guard let end = cal.date(byAdding: .day, value: Self.boostWindowDays - 1, to: start),
                          let startIdx = days.firstIndex(of: start) else { continue }
                    var gain = 0
                    var covered = 0
                    for day in days[startIdx...] where day <= end {
                        gain += netByDay[day] ?? 0
                        covered += 1
                    }
                    if covered >= 2 && gain > bestGain {
                        bestGain = gain
                        bestStart = start
                    }
                }
                if bestGain > 0 {
                    events.append(MilestoneEvent(
                        kind: .boostWeek,
                        date: bestStart,
                        value: bestGain,
                        secondaryValue: Self.boostWindowDays
                    ))
                }
            }
        }

        let sortedEvents = events.sorted { $0.date < $1.date }
        let bestPost = sortedEvents.last { $0.kind == .bestPost }
        return MilestoneResult(events: sortedEvents, bestPost: bestPost)
    }
}
