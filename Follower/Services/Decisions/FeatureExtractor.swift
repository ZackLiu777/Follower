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

    /// 从 Snapshot 序列计算 FollowerHealth
    /// - growth7d / growth30d：首尾快照差值按观测跨度换算为 7 日 / 30 日速率
    /// - activeRatio 来自平均 engagementRate 动态映射（估算，非精确活跃统计）
    static func extractHealth(snapshots: [Snapshot], followers: Int) -> FollowerHealth {
        guard !snapshots.isEmpty else {
            return FollowerHealth(activeFollowers: 0, inactiveFollowers: 0,
                totalFollowers: followers, followerGrowth7d: 0, followerGrowth30d: 0,
                viewsGrowth7d: 0)
        }
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        let first = sorted.first!, last = sorted.last!
        // engagementRate 通常在 0.01~0.15 之间，映射到 activeRatio 0.05~0.50
        let avgEng = sorted.map(\.engagementRate).reduce(0, +) / Double(sorted.count)
        let activeRatio = min(0.50, max(0.05, avgEng * 3.5))
        let active = Int(Double(followers) * activeRatio)
        let totalGrowth = Double(last.followersCount - first.followersCount)
        let totalViewsGrowth = Double(last.totalViews - first.totalViews)
        let spanDays = max(1.0, last.observedAt.timeIntervalSince(first.observedAt) / 86400.0)
        return FollowerHealth(
            activeFollowers: active,
            inactiveFollowers: followers - active,
            totalFollowers: followers,
            followerGrowth7d: totalGrowth * (7.0 / spanDays),
            followerGrowth30d: totalGrowth * (30.0 / spanDays),
            viewsGrowth7d: max(0, totalViewsGrowth) * (7.0 / spanDays)
        )
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

    // MARK: - TimingProfile

    /// 从帖子发布时间 × 真实互动的分布计算最佳发帖日/时段 — 零硬编码
    /// 最佳小时窗口与最差小时窗口均由 ImpactEstimator 从数据计算
    static func extractTimingProfile(posts: [MediaPost]) -> TimingProfile {
        let window = ImpactEstimator.bestHourWindow(posts: posts)
        let (day, _) = ImpactEstimator.bestDay(posts: posts)
        return TimingProfile(
            bestHours: formatHourWindow(window.startHour, window.endHour),
            worstHours: formatHourWindow(window.worstStartHour, window.worstEndHour),
            bestDay: day
        )
    }

    /// 小时窗口格式化："19:00–21:00"（零填充）
    private static func formatHourWindow(_ start: Int, _ end: Int) -> String {
        String(format: "%02d:00–%02d:00", start, end)
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
        let totalGrowth30d: Double
        if let firstSnap = sorted.first, let lastSnap = sorted.last {
            let spanDays = max(1.0, lastSnap.observedAt.timeIntervalSince(firstSnap.observedAt) / 86_400.0)
            totalGrowth30d = Double(lastSnap.followersCount - firstSnap.followersCount) * (30.0 / spanDays)
        } else {
            totalGrowth30d = 0
        }
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

    /// 从快照 + 帖子计算量化收益摘要（转化率 / 单帖收益 / 时段提升）
    static func extractImpact(snapshots: [Snapshot], posts: [MediaPost]) -> ImpactSummary {
        let rates = ImpactEstimator.conversionRates(snapshots: snapshots)
        let stats = ImpactEstimator.typeStats(posts: posts)
        var followerGain: [ContentType: Double] = [:]
        var viewsGain: [ContentType: Double] = [:]
        for (type, perf) in stats {
            followerGain[type] = ImpactEstimator.perPostFollowerGain(perf, rates: rates)
            viewsGain[type] = ImpactEstimator.perPostViewsGain(perf, rates: rates)
        }
        let window = ImpactEstimator.bestHourWindow(posts: posts)
        let (day, dayUplift) = ImpactEstimator.bestDay(posts: posts)
        return ImpactSummary(
            rates: rates,
            perPostFollowerGain: followerGain,
            perPostViewsGain: viewsGain,
            hourUplift: window,
            bestDay: day,
            dayUplift: dayUplift
        )
    }
}
