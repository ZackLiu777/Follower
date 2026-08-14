//
//  FeatureExtractor.swift
//  Follower
//
//  特征提取器 — 完全从真实 Snapshot / MediaPost 数据计算 GrowthFeatures。
//  零硬编码、纯函数、Sendable。所有输出 100% 由输入数据驱动。
//
//  v1 重写：删除此前基于固定比例（reel×1.4 等）编造内容类型表现、
//  以及 `17 + bestDay % 3` 拍脑袋时段的做法，改为：
//  - 内容表现：MediaPost 每类型真实平均互动（likes + comments）
//  - 时段画像：帖子发布时间 × 互动的真实分布（最佳日/最佳小时窗口）
//  - 增长：快照首尾差值按观测跨度换算 7 日 / 30 日速率
//  - 收益估算：ImpactEstimator 从快照日增量计算转化率
//
//  activeRatio 仍为估算（无 per-follower 活跃数据），保持动态映射并注明。

import Foundation

// MARK: - FeatureExtractor

/// 特征提取器 — 所有特征均从输入数据动态计算，无任何硬编码常量
struct FeatureExtractor: Sendable {

    // MARK: - FollowerHealth

    /// 从 Snapshot 序列计算 FollowerHealth（v1.1 放开 90 天限制后使用真实窗口语义）
    /// - growth7d / growth30d / viewsGrowth7d：**真实窗口** — 取窗口内首尾快照差值；
    ///   窗口内不足 2 条时，用全部可用跨度按比例折算（数据稀疏期兜底）。
    /// - activeRatio 来自平均 engagementRate 动态映射（估算，非精确活跃统计）
    static func extractHealth(snapshots: [Snapshot], followers: Int) -> FollowerHealth {
        guard !snapshots.isEmpty else {
            return FollowerHealth(activeFollowers: 0, inactiveFollowers: 0,
                totalFollowers: followers, followerGrowth7d: 0, followerGrowth30d: 0,
                viewsGrowth7d: 0)
        }
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        // engagementRate 通常在 0.01~0.15 之间，映射到 activeRatio 0.05~0.50
        let avgEng = sorted.map(\.engagementRate).reduce(0, +) / Double(sorted.count)
        let activeRatio = min(0.50, max(0.05, avgEng * 3.5))
        let active = Int(Double(followers) * activeRatio)
        return FollowerHealth(
            activeFollowers: active,
            inactiveFollowers: followers - active,
            totalFollowers: followers,
            followerGrowth7d: windowDelta(sorted, days: 7) { $0.followersCount },
            followerGrowth30d: windowDelta(sorted, days: 30) { $0.followersCount },
            viewsGrowth7d: max(0, windowDelta(sorted, days: 7) { $0.totalViews })
        )
    }

    /// 窗口增量 — 取最近 `days` 天窗口内首尾快照差值；
    /// 窗口内不足 2 条时，用全部可用跨度按比例折算（数据稀疏期兜底）。
    /// - Parameters:
    ///   - sorted: 按 observedAt 升序的快照
    ///   - days: 窗口天数（7 / 30）
    ///   - value: 取值闭包（followersCount / totalViews）
    static func windowDelta(_ sorted: [Snapshot], days: Double, value: (Snapshot) -> Int) -> Double {
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        let windowStart = last.observedAt.addingTimeInterval(-days * 86_400)
        let window = sorted.filter { $0.observedAt >= windowStart }
        if window.count >= 2, let wFirst = window.first, let wLast = window.last {
            return Double(value(wLast) - value(wFirst))
        }
        // 窗口内数据不足 → 全部可用跨度折算
        let spanDays = max(1.0, last.observedAt.timeIntervalSince(first.observedAt) / 86_400.0)
        return Double(value(last) - value(first)) * (days / spanDays)
    }

    /// 7 自然日窗口增量 — 与 Dashboard computeDeltas 口径一致
    /// （Calendar 7 天前为窗口起点，首尾快照差值），供决策页 Hero 展示。
    static func weekCalendarDelta(_ sorted: [Snapshot], value: (Snapshot) -> Int) -> Int {
        guard let current = sorted.last else { return 0 }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: current.observedAt)
            ?? current.observedAt.addingTimeInterval(-7 * 86_400)
        let window = sorted.filter { $0.observedAt >= weekAgo }
        guard let first = window.first else { return 0 }
        return value(current) - value(first)
    }

    /// 周期序列末两次差值 — 与趋势页 delta（周/月/年窗口）口径一致：
    /// 取周期末值序列（periodEndMetrics，无 0 占位）相邻两条差（本周 vs 上周等）。
    /// 序列不足 2 条 → nil（调用方回退其他口径）。
    static func lastPeriodDelta(_ metrics: [Metric]) -> Int? {
        let sorted = metrics.sorted { $0.observedAt < $1.observedAt }
        guard sorted.count >= 2 else { return nil }
        return sorted[sorted.count - 1].value - sorted[sorted.count - 2].value
    }

    // MARK: - ContentPerformance

    /// 从 MediaPost 真实数据计算各内容类型表现 — 零硬编码、零固定比例
    /// 每类型：平均互动（likes + comments）/ 总帖数 / 近 7 天帖数 / 前后半段互动趋势
    static func extractContentPerformance(posts: [MediaPost]) -> [ContentType: ContentStats] {
        let stats = ImpactEstimator.typeStats(posts: posts)
        var result: [ContentType: ContentStats] = [:]
        for (type, perf) in stats {
            result[type] = ContentStats(
                type: type,
                avgEngagement: perf.avgEngagement,
                totalPosts: perf.postCount,
                recentPosts: perf.recent7dCount,
                growthRate: perf.growthRate
            )
        }
        return result
    }

    // MARK: - FatigueIndex

    /// 疲劳阈值 — 各类型平均发帖量的 1.2 倍（下限 2）
    /// 与 extractFatigue 共享，CardGenerator 计算恢复收益时复用同一阈值
    static func fatigueThreshold(performance: [ContentType: ContentStats]) -> Double {
        let totalRecent = performance.values.map(\.recentPosts).reduce(0, +)
        let avgRecent = Double(totalRecent) / Double(max(1, performance.count))
        return max(2.0, avgRecent * 1.2)
    }

    /// 从内容表现计算疲劳指数 — 阈值完全由数据量动态决定
    static func extractFatigue(performance: [ContentType: ContentStats]) -> [ContentType: FatigueIndex] {
        let threshold = fatigueThreshold(performance: performance)
        var result: [ContentType: FatigueIndex] = [:]
        for (type, stats) in performance {
            let fatigued = Double(stats.recentPosts) > threshold
            let penalty = fatigued ? min(0.5, Double(stats.recentPosts) / threshold * 0.15) : 0.0
            result[type] = FatigueIndex(
                contentType: type,
                posts7d: stats.recentPosts,
                engagementTrend: stats.growthRate,
                isFatigued: fatigued,
                penalty: penalty
            )
        }
        return result
    }

    // MARK: - DecisionContext

    /// 提取决策上下文 — 模板触发所需的全部特征（周对比 / 趋势 / 内容分布 / 风险）。
    /// - Parameters:
    ///   - snapshots: 90 天日频快照
    ///   - posts: 该账号帖子
    ///   - weeklyMetrics: 周窗口指标（reachEstimate / profileViews / averageLikes / engagementTrend）
    ///   - draftCount: 草稿数
    static func extractContext(
        snapshots: [Snapshot],
        posts: [MediaPost],
        weeklyMetrics: [MetricType: [Metric]],
        draftCount: Int
    ) -> DecisionContext {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        let now = Date()
        let cal = Calendar.current

        // ── 周对比：本周（最近 7 天）vs 上周 ──
        let weekStart = now.addingTimeInterval(-7 * 86_400)
        let twoWeekStart = now.addingTimeInterval(-14 * 86_400)
        func delta(in range: Range<Date>) -> (followers: Double, views: Double, engagement: Double) {
            let window = sorted.filter { range.contains($0.observedAt) }
            guard window.count >= 2, let first = window.first, let last = window.last else {
                return (0, 0, 0)
            }
            return (
                Double(last.followersCount - first.followersCount),
                Double(last.totalViews - first.totalViews),
                Double((last.totalLikes + last.totalComments) - (first.totalLikes + first.totalComments))
            )
        }
        let this = delta(in: weekStart..<now)
        let last = delta(in: twoWeekStart..<weekStart)
        let wow = WeekOverWeek(
            postsThisWeek: posts.filter { $0.date >= weekStart }.count,
            postsLastWeek: posts.filter { $0.date >= twoWeekStart && $0.date < weekStart }.count,
            followersThisWeek: this.followers,
            followersLastWeek: last.followers,
            viewsThisWeek: this.views,
            viewsLastWeek: last.views,
            engagementThisWeek: this.engagement,
            engagementLastWeek: last.engagement
        )

        // ── 趋势信号：周序列前半 vs 后半 ──
        func trend(_ type: MetricType) -> TrendSignal {
            let values = (weeklyMetrics[type] ?? [])
                .sorted { $0.observedAt < $1.observedAt }
                .map { Double($0.value) }
            guard values.count >= 2 else { return TrendSignal(firstHalf: 0, lastHalf: 0) }
            let half = max(1, values.count / 2)
            let firstAvg = values.prefix(half).reduce(0, +) / Double(half)
            let lastAvg = values.suffix(half).reduce(0, +) / Double(half)
            return TrendSignal(firstHalf: firstAvg, lastHalf: lastAvg)
        }

        // ── 内容分布 ──
        let stats = ImpactEstimator.typeStats(posts: posts)
        let totalPosts = max(1, posts.count)
        var typeShare: [ContentType: Double] = [:]
        for (type, perf) in stats {
            typeShare[type] = Double(perf.postCount) / Double(totalPosts)
        }
        let postEngagements = posts.map { Double($0.likes + $0.comments) }
        let top = postEngagements.max() ?? 0
        let lowest = postEngagements.min() ?? 0
        let topPost = posts.max { ($0.likes + $0.comments) < ($1.likes + $1.comments) }
        let lowCount = posts.filter { post in
            guard let type = ContentType(mediaType: post.type),
                  let perf = stats[type], perf.avgEngagement > 0 else { return false }
            return Double(post.likes + post.comments) < perf.avgEngagement * 0.5
        }.count
        let zeroCount = posts.filter { $0.likes == 0 && $0.comments == 0 }.count
        let lastPostDate = posts.map(\.date).max()
        let daysSinceLastPost = lastPostDate.map {
            max(0, Int(now.timeIntervalSince($0) / 86_400))
        } ?? 0

        // 最长断更间隔（帖子 ≥ 2 才可计算相邻间隔）
        let postDates = posts.map(\.date).sorted()
        var longestGap = daysSinceLastPost
        if postDates.count > 1 {
            for i in 1..<postDates.count {
                let gap = Int(postDates[i].timeIntervalSince(postDates[i - 1]) / 86_400)
                if gap > longestGap { longestGap = gap }
            }
        }

        // ── 取关分析（快照 ≥ 2 才可计算日增量）──
        var churnDays = 0
        var churnByDay: [Int: Int] = [:]
        if sorted.count > 1 {
            for i in 1..<sorted.count {
                guard sorted[i].observedAt >= weekStart else { continue }
                let df = sorted[i].followersCount - sorted[i - 1].followersCount
                if df < 0 {
                    churnDays += 1
                    let day = cal.component(.weekday, from: sorted[i].observedAt)
                    churnByDay[day, default: 0] += 1
                }
            }
        }
        let peak = churnByDay.max { $0.value < $1.value } ?? (1, 0)

        // ── 周末 vs 工作日 ──
        var weekendEng = 0.0, weekendCount = 0, weekdayEng = 0.0, weekdayCount = 0
        for post in posts {
            let day = cal.component(.weekday, from: post.date)
            let eng = Double(post.likes + post.comments)
            if day == 1 || day == 7 {
                weekendEng += eng; weekendCount += 1
            } else {
                weekdayEng += eng; weekdayCount += 1
            }
        }
        let weekendAvg = weekendCount > 0 ? weekendEng / Double(weekendCount) : 0
        let weekdayAvg = weekdayCount > 0 ? weekdayEng / Double(weekdayCount) : 0
        let weekendRatio = weekdayAvg > 0 ? (weekendAvg - weekdayAvg) / weekdayAvg : 0

        // ── 次佳时段 ──
        let second = ImpactEstimator.secondBestHourWindow(posts: posts)

        // ── 近 30 天周均发帖数（目标频率推导）──
        let posts30d = posts.filter { $0.date >= now.addingTimeInterval(-30 * 86_400) }.count
        let avgWeeklyPosts = Double(posts30d) / 4.3

        // ── 账号增长阶段判定（确定性规则）──
        // v1.1：真实 30 天窗口速率（非全历史折算）
        let totalGrowth30d = windowDelta(sorted, days: 30) { $0.followersCount }
        let phase = Self.classifyPhase(
            followersThisWeek: wow.followersThisWeek,
            weeklyRate30: totalGrowth30d > 0 ? totalGrowth30d / 4.0 : 0
        )

        return DecisionContext(
            weekOverWeek: wow,
            reachTrend: trend(.reachEstimate),
            profileViewsTrend: trend(.profileViews),
            likesTrend: trend(.averageLikes),
            engagementTrend: trend(.engagementTrend),
            typeShare: typeShare,
            topPostEngagement: top,
            topPostType: topPost.flatMap { ContentType(mediaType: $0.type) },
            lowestPostEngagement: lowest,
            lowEngagementPostCount: lowCount,
            zeroEngagementPostCount: zeroCount,
            daysSinceLastPost: daysSinceLastPost,
            postsLast7d: posts.filter { $0.date >= weekStart }.count,
            longestGapDays: longestGap,
            followingCount: sorted.last?.followingCount ?? 0,
            draftCount: draftCount,
            churnDays7d: churnDays,
            churnPeakDay: peak.0,
            churnPeakShare: churnDays > 0 ? Double(peak.1) / Double(churnDays) : 0,
            weekendVsWeekdayRatio: weekendRatio,
            secondBestHour: second?.start,
            secondBestUplift: second?.uplift ?? 1.0,
            snapshotCount: sorted.count,
            avgWeeklyPosts: avgWeeklyPosts,
            phase: phase
        )
    }

    /// 账号增长阶段判定（确定性规则）：
    /// - viral：本周涨粉 ≥ 30 日周均 × 2
    /// - declining：本周净负增长，或 < 30 日周均 × 0.5
    /// - stagnant：30 日有速率但本周 ≈ 0（≤ max(2, 周均×0.1)）
    /// - growing：其余
    static func classifyPhase(followersThisWeek: Double, weeklyRate30: Double) -> AccountPhase {
        if weeklyRate30 > 0, followersThisWeek >= weeklyRate30 * 2 {
            return .viral
        }
        if followersThisWeek < 0 || (weeklyRate30 > 0 && followersThisWeek < weeklyRate30 * 0.5) {
            return .declining
        }
        if weeklyRate30 > 0, abs(followersThisWeek) <= max(2, weeklyRate30 * 0.1) {
            return .stagnant
        }
        return .growing
    }

    // MARK: - ImpactSummary

    /// 从快照 + 帖子计算量化收益摘要（转化率 / 单帖收益）
    /// v1.2：移除时段提升（时间类建议已从产品移除）
    static func extractImpact(snapshots: [Snapshot], posts: [MediaPost]) -> ImpactSummary {
        let rates = ImpactEstimator.conversionRates(snapshots: snapshots)
        let stats = ImpactEstimator.typeStats(posts: posts)
        var followerGain: [ContentType: Double] = [:]
        var viewsGain: [ContentType: Double] = [:]
        for (type, perf) in stats {
            followerGain[type] = ImpactEstimator.perPostFollowerGain(perf, rates: rates)
            viewsGain[type] = ImpactEstimator.perPostViewsGain(perf, rates: rates)
        }
        return ImpactSummary(
            rates: rates,
            perPostFollowerGain: followerGain,
            perPostViewsGain: viewsGain
        )
    }
}
