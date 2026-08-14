//
//  ImpactEstimator.swift
//  Follower
//
//  收益估算器 — 从真实 Snapshot / MediaPost 数据计算量化收益指标。
//  纯函数，Sendable，确定性，零硬编码：所有估算均基于历史数据中的
//  可测量比例（浏览→涨粉、点赞→浏览）与真实分类型/分时段表现。
//
//  估算链路（每个环节均可测量，文档注明为估算而非精确值）：
//  1. 转化率：从快照日增量 ΣΔ粉丝 / ΣΔ浏览、ΣΔ粉丝 / ΣΔ点赞、ΣΔ浏览 / ΣΔ点赞
//  2. 分类型表现：MediaPost 每类型真实平均点赞/评论
//  3. 时段提升：按帖子发布时间分桶，最佳窗口平均互动 ÷ 整体平均
//
//  注意：Instagram API 无"单帖带来多少粉丝"字段，所有粉丝收益均为
//  基于转化率的估算，非精确归因。

import Foundation

// MARK: - ContentType ↔ MediaPostType 映射

extension ContentType {
    /// 将存储层的帖子类型映射为决策引擎的内容类型
    init?(mediaType: MediaPostType) {
        switch mediaType {
        case .video:     self = .reel
        case .carousel:  self = .carousel
        case .image:     self = .photo
        }
    }
}

// MARK: - ImpactEstimator

/// 收益估算器 — 计算建议背后的量化收益（涨粉数 / 浏览数）
struct ImpactEstimator: Sendable {

    // MARK: - 输出结构

    /// 账号级转化率 — 由快照日增量计算
    struct ConversionRates: Sendable {
        /// ΣΔ粉丝 / ΣΔ浏览（每次浏览带来的粉丝，仅计正向增量）
        let followerPerView: Double
        /// ΣΔ粉丝 / ΣΔ点赞（每次点赞带来的粉丝）
        let followerPerLike: Double
        /// ΣΔ浏览 / ΣΔ点赞（每次点赞对应的浏览数）
        let viewsPerLike: Double
    }

    /// 单种内容类型的真实表现统计
    struct TypePerformance: Sendable {
        let type: ContentType
        let avgLikes: Double
        let avgComments: Double
        /// 平均互动 = 平均点赞 + 平均评论
        let avgEngagement: Double
        let postCount: Int
        /// 最近 7 天发帖数
        let recent7dCount: Int
        /// 互动趋势：后半段平均互动 vs 前半段（正=改善）
        let growthRate: Double
    }

    // MARK: - 转化率

    /// 从快照日增量计算账号级转化率。
    /// - Parameter snapshots: 按时间排序的日频快照（内部会再排序）
    /// - Returns: 转化率；数据不足或增量为 0 时对应项为 0
    static func conversionRates(snapshots: [Snapshot]) -> ConversionRates {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard sorted.count >= 2 else {
            return ConversionRates(followerPerView: 0, followerPerLike: 0, viewsPerLike: 0)
        }
        var sumF = 0, sumV = 0, sumL = 0
        for i in 1..<sorted.count {
            let df = sorted[i].followersCount - sorted[i - 1].followersCount
            let dv = sorted[i].totalViews - sorted[i - 1].totalViews
            let dl = sorted[i].totalLikes - sorted[i - 1].totalLikes
            // 转化率只衡量"获得"侧：负增量（取关/浏览下降）不参与
            sumF += max(0, df)
            sumV += max(0, dv)
            sumL += max(0, dl)
        }
        return ConversionRates(
            followerPerView: sumV > 0 ? Double(sumF) / Double(sumV) : 0,
            followerPerLike: sumL > 0 ? Double(sumF) / Double(sumL) : 0,
            viewsPerLike:    sumL > 0 ? Double(sumV) / Double(sumL) : 0
        )
    }

    // MARK: - 分类型表现

    /// 从 MediaPost 计算各内容类型的真实表现。
    /// - Parameter posts: 该账号的帖子（任意顺序，内部按日期分析）
    /// - Returns: 有帖子的类型 → 表现统计；无帖子类型不出现
    static func typeStats(posts: [MediaPost]) -> [ContentType: TypePerformance] {
        let now = Date()
        var byType: [ContentType: [MediaPost]] = [:]
        for post in posts {
            guard let type = ContentType(mediaType: post.type) else { continue }
            byType[type, default: []].append(post)
        }
        var result: [ContentType: TypePerformance] = [:]
        for (type, list) in byType {
            let sorted = list.sorted { $0.date < $1.date }
            let likes = sorted.map { Double($0.likes) }.reduce(0, +)
            let comments = sorted.map { Double($0.comments) }.reduce(0, +)
            let avgLikes = likes / Double(sorted.count)
            let avgComments = comments / Double(sorted.count)
            let eng = sorted.map { Double($0.likes + $0.comments) }
            let avgEng = eng.reduce(0, +) / Double(sorted.count)
            let half = max(1, sorted.count / 2)
            let firstAvg = eng.prefix(half).reduce(0, +) / Double(half)
            let lastAvg = eng.suffix(half).reduce(0, +) / Double(half)
            let growth = firstAvg > 0 ? (lastAvg - firstAvg) / firstAvg : 0.0
            let recent = sorted.filter { $0.date >= now.addingTimeInterval(-7 * 86_400) }.count
            result[type] = TypePerformance(
                type: type,
                avgLikes: avgLikes,
                avgComments: avgComments,
                avgEngagement: avgEng,
                postCount: sorted.count,
                recent7dCount: recent,
                growthRate: growth
            )
        }
        return result
    }

    /// 平均每帖带来的粉丝（估算）：平均点赞 × 点赞→粉丝转化率
    static func perPostFollowerGain(_ perf: TypePerformance, rates: ConversionRates) -> Double {
        perf.avgLikes * rates.followerPerLike
    }

    /// 平均每帖带来的浏览（估算）：平均点赞 × 点赞→浏览比例
    static func perPostViewsGain(_ perf: TypePerformance, rates: ConversionRates) -> Double {
        perf.avgLikes * rates.viewsPerLike
    }

    // MARK: - 时段排名（v1.2 起仅供 DecisionContext 的 secondBestHour 使用）

    /// 全部小时窗口按平均互动降序排名（每窗口 = 起始小时 [h, h+2] 内有数据的整点）。
    /// - Returns: [(start, end, avg, uplift)]；帖子 < 2 或互动为 0 → 空
    static func hourWindowRanks(posts: [MediaPost]) -> [(start: Int, end: Int, avg: Double, uplift: Double)] {
        guard posts.count >= 2 else { return [] }
        let cal = Calendar.current
        var byHour: [Int: [Double]] = [:]
        for post in posts {
            let h = cal.component(.hour, from: post.date)
            byHour[h, default: []].append(Double(post.likes + post.comments))
        }
        let hours = byHour.keys.sorted()
        guard !hours.isEmpty else { return [] }
        let overallAvg = byHour.values.flatMap { $0 }.reduce(0, +) / Double(posts.count)
        guard overallAvg > 0 else { return [] }

        func windowAvg(_ h: Int) -> (avg: Double, end: Int)? {
            var sum = 0.0, count = 0, last = h
            for k in h...(h + 2) {
                guard let values = byHour[k] else { continue }
                sum += values.reduce(0, +)
                count += values.count
                last = k
            }
            guard count > 0 else { return nil }
            return (sum / Double(count), last)
        }

        var ranks: [(start: Int, end: Int, avg: Double, uplift: Double)] = []
        for h in hours {
            guard let (avg, end) = windowAvg(h) else { continue }
            ranks.append((start: h, end: end, avg: avg, uplift: avg / overallAvg))
        }
        return ranks.sorted { $0.avg > $1.avg }
    }

    /// 次佳时段窗口（第二高平均互动的起始小时），提升倍数 > 1 才返回
    static func secondBestHourWindow(posts: [MediaPost]) -> (start: Int, uplift: Double)? {
        let ranks = hourWindowRanks(posts: posts)
        guard ranks.count >= 2, ranks[1].uplift > 1.0 else { return nil }
        return (ranks[1].start, ranks[1].uplift)
    }
}
