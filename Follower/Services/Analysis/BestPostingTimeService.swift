//
//  BestPostingTimeService.swift
//  Follower
//
//  Sigma: 最佳发帖时间服务（Premium）— 与互动热力图（Event+快照）数据源分离。
//  基于 MediaPost（真实帖子数据）按发布时间聚合互动表现（likes + comments）。
//
//  v2 指标重设计（替代"无收缩的最大值"）：
//  - 24×1h 内部桶 → 滑动 3h 连续窗口
//  - 收缩估计（shrinkage）：μ̂ = (n/(n+k))·μ + (k/(n+k))·μ_global，k=8
//    —— 小样本桶自动向账号基线收缩，杜绝"2 篇爆帖宣称最佳时段"的伪精确
//  - 相对基线提升：lift = μ̂/μ_global − 1
//  - seeded bootstrap（固定 seed 42，500 次重采样）→ P(该窗口成为最佳)
//  - confidence 分档（窗口样本量：<5 Low / 5-19 Medium / ≥20 High）
//  - 综合评分：50%·lift 归一化 + 30%·confidence 归一化 + 20%·P(best)
//
//  职责分层：Service 完成全部统计推断（确定性可测），View 只负责呈现。
//  历史层（气泡矩阵 / 小时 / 星期分布）保留原始平均值 —— 诚实呈现事实；
//  推荐层（recommendation）使用收缩估计 —— 统计稳健的结论。

import Foundation

// MARK: - ConfidenceLevel

/// 推荐置信度 — 由最佳窗口样本量分档
enum ConfidenceLevel: String, Sendable {
    case low, medium, high
}

// MARK: - PostingTimeRecommendation

/// 发帖时间推荐 — 统计推断后的结论（View 直接呈现，不参与推导）
struct PostingTimeRecommendation: Sendable {
    /// 最佳发帖日（Calendar weekday 1=Sun...7=Sat）
    let weekday: Int
    /// 最佳窗口起始小时（0-23）
    let startHour: Int
    /// 最佳窗口结束小时（0-23，含）
    let endHour: Int
    /// 综合评分 0-100（lift + confidence + probability 加权）
    let score: Int
    /// 窗口收缩后期望互动
    let expectedEngagement: Double
    /// 相对账号基线的提升（μ̂/μ_global − 1，可为负）
    let liftVsAverage: Double
    /// 成为最佳窗口的概率（bootstrap 频率 0-1）
    let probabilityOfBeingBest: Double
    /// 窗口内样本量
    let sampleCount: Int
}

// MARK: - BestTimeBubbleCell

/// 气泡矩阵单元格：(weekday, 3 小时桶) 的平均互动与样本量（历史层，原始平均值）。
struct BestTimeBubbleCell: Sendable {
    /// Calendar weekday（1=Sun...7=Sat）
    let weekday: Int
    /// 3 小时桶索引（0-7 → 00:00-02:59 ... 21:00-23:59）
    let hourBucket: Int
    /// 该桶平均互动（无样本时为 0）
    let avgEngagement: Double
    /// 该桶帖子数（样本量）
    let postCount: Int
}

// MARK: - BestPostingTimeResult

/// 最佳发帖时间结果：推荐（收缩后）+ 历史证据（原始分布）
struct BestPostingTimeResult: Sendable {
    /// 推荐层 — 收缩估计后的结论
    let recommendation: PostingTimeRecommendation
    /// 推荐置信度
    let confidence: ConfidenceLevel
    /// 账号基线 — 全部帖子平均互动
    let accountAverageEngagement: Double

    // ── 历史层（原始平均值，诚实呈现）──
    /// 每小时互动量（24 个，归一化峰值=1.0，索引 = hour 0-23）
    let hourValues: [Double]
    /// 每星期互动量（7 个，Sun-first 与 Calendar 一致，归一化）
    let dayValues: [Double]
    /// 7×8 气泡矩阵（7 天 × 每 3 小时桶，共 56 格，含空桶）
    let matrixCells: [BestTimeBubbleCell]
    /// 矩阵内最佳格（原始平均互动峰值）；无样本时 nil
    let bestBubble: BestTimeBubbleCell?
    /// 参与统计的帖子数
    let totalPosts: Int
    /// 平均每帖互动（likes + comments）
    let avgEngagementPerPost: Double

    /// 最佳发帖小时（= recommendation.startHour，兼容旧 UI 字段）
    var bestHour: Int { recommendation.startHour }
    /// 最佳发帖日（= recommendation.weekday，兼容旧 UI 字段）
    var bestDay: Int { recommendation.weekday }
    /// 最佳时段描述（如 "Wed 18:00–21:00"，数据层英文）
    var peakDescription: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = dayNames.indices.contains(recommendation.weekday - 1) ? dayNames[recommendation.weekday - 1] : "?"
        return "\(day) \(String(format: "%02d:00", recommendation.startHour))–\(String(format: "%02d:00", recommendation.endHour))"
    }

    /// 查询指定星期的互动量（index 0=Sun...6=Sat）
    func dayValue(weekday: Int) -> Double {
        dayValues.indices.contains(weekday - 1) ? dayValues[weekday - 1] : 0
    }

    /// 查询指定 (weekday, hourBucket) 的气泡格；无样本返回 nil
    func bubbleCell(weekday: Int, hourBucket: Int) -> BestTimeBubbleCell? {
        matrixCells.first { $0.weekday == weekday && $0.hourBucket == hourBucket }
    }
}

// MARK: - BestPostingTimeServiceProtocol

protocol BestPostingTimeServiceProtocol: Sendable {
    /// 基于 MediaPost 发布时间生成最佳发帖时间分析
    func analyze(from posts: [MediaPost]) async -> BestPostingTimeResult
}

// MARK: - BestPostingTimeService

/// 最佳发帖时间服务 — 统计推断（shrinkage + bootstrap），确定性可测。
/// 生产固定 seed（42）：同数据必同输出，测试可精确断言。
final class BestPostingTimeService: BestPostingTimeServiceProtocol {

    /// 收缩强度（先验等效样本量）：8 帖以下强烈依赖账号基线
    static let shrinkK = 8.0
    /// 推荐窗口宽度（小时）
    static let windowHours = 3
    /// bootstrap 重采样次数
    static let bootstrapSamples = 500
    /// 确定性种子（生产与测试共用）
    static let bootstrapSeed: UInt64 = 42

    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 1  // Sunday = 1
        return c
    }()

    func analyze(from posts: [MediaPost]) async -> BestPostingTimeResult {
        guard !posts.isEmpty else { return emptyResult() }
        var rng = SeededRandom(seed: Self.bootstrapSeed)

        // ── 1. 24×1h 桶聚合（n 与互动和）──
        var hourCount = [Int](repeating: 0, count: 24)
        var hourSum = [Double](repeating: 0, count: 24)
        var dayCount = [Int](repeating: 0, count: 7)
        var daySum = [Double](repeating: 0, count: 7)
        var bucketTotals = [Double](repeating: 0, count: 7 * 8)
        var bucketPosts = [Int](repeating: 0, count: 7 * 8)

        for post in posts {
            let hr = calendar.component(.hour, from: post.date)
            let wd = calendar.component(.weekday, from: post.date)
            let eng = Double(post.likes + post.comments)
            hourCount[hr] += 1; hourSum[hr] += eng
            dayCount[wd - 1] += 1; daySum[wd - 1] += eng
            let idx = (wd - 1) * 8 + hr / 3
            bucketTotals[idx] += eng
            bucketPosts[idx] += 1
        }

        let muGlobal = hourSum.reduce(0, +) / Double(posts.count)

        // ── 2. 收缩估计 + 滑动 3h 窗口评分 ──
        let shrunk: (Int, Double) -> Double = { n, sum in
            Self.shrunkMean(n: n, sum: sum, muGlobal: muGlobal)
        }

        // 窗口聚合（跨 0 点环绕）
        func windowStats(start: Int) -> (n: Int, sum: Double) {
            var n = 0, s = 0.0
            for d in 0..<Self.windowHours {
                let h = (start + d) % 24
                n += hourCount[h]; s += hourSum[h]
            }
            return (n, s)
        }

        var bestStart = 0
        var bestMuHat = -Double.greatestFiniteMagnitude
        for h in 0..<24 {
            let (n, s) = windowStats(start: h)
            let muHat = shrunk(n, s)
            if muHat > bestMuHat { bestMuHat = muHat; bestStart = h }
        }
        let (bestN, bestSum) = windowStats(start: bestStart)
        let bestWindowMuHat = shrunk(bestN, bestSum)

        // ── 3. 最佳日（星期桶收缩均值）──
        var bestDayIdx = 0
        var bestDayMuHat = -Double.greatestFiniteMagnitude
        for d in 0..<7 {
            let muHat = shrunk(dayCount[d], daySum[d])
            if muHat > bestDayMuHat { bestDayMuHat = muHat; bestDayIdx = d }
        }

        // ── 4. seeded bootstrap → P(该窗口成为最佳) ──
        let probability = bootstrapProbability(
            posts: posts,
            muGlobal: muGlobal,
            targetStart: bestStart,
            using: &rng
        )

        // ── 5. confidence + lift + score ──
        let confidence: ConfidenceLevel
        if bestN < 5 { confidence = .low }
        else if bestN < 20 { confidence = .medium }
        else { confidence = .high }

        let lift = muGlobal > 0 ? bestWindowMuHat / muGlobal - 1 : 0

        // score = 50%·lift 归一化 + 30%·confidence 归一化 + 20%·P(best)
        let liftNorm = min(1.0, max(0.0, lift))
        let confNorm: Double = switch confidence {
        case .low: 0.3
        case .medium: 0.65
        case .high: 1.0
        }
        let score = Int((100 * (0.5 * liftNorm + 0.3 * confNorm + 0.2 * probability)).rounded())

        let recommendation = PostingTimeRecommendation(
            weekday: bestDayIdx + 1,
            startHour: bestStart,
            endHour: (bestStart + Self.windowHours - 1) % 24,
            score: min(100, max(1, score)),
            expectedEngagement: bestWindowMuHat,
            liftVsAverage: lift,
            probabilityOfBeingBest: probability,
            sampleCount: bestN
        )

        // ── 6. 历史层（原始平均值）──
        func normalized(_ values: [Double]) -> [Double] {
            let peak = values.max() ?? 1
            return values.map { $0 / max(peak, 1) }
        }
        let hourValues = normalized((0..<24).map {
            hourCount[$0] > 0 ? hourSum[$0] / Double(hourCount[$0]) : 0
        })
        let dayValues = normalized((0..<7).map { daySum[$0] / Double(max(1, dayCount[$0])) })

        var matrixCells: [BestTimeBubbleCell] = []
        for wd in 1...7 {
            for b in 0..<8 {
                let idx = (wd - 1) * 8 + b
                matrixCells.append(BestTimeBubbleCell(
                    weekday: wd, hourBucket: b,
                    avgEngagement: bucketPosts[idx] > 0 ? bucketTotals[idx] / Double(bucketPosts[idx]) : 0,
                    postCount: bucketPosts[idx]
                ))
            }
        }
        let bestBubble = matrixCells
            .filter { $0.postCount > 0 }
            .max(by: { $0.avgEngagement < $1.avgEngagement })

        return BestPostingTimeResult(
            recommendation: recommendation,
            confidence: confidence,
            accountAverageEngagement: muGlobal,
            hourValues: hourValues,
            dayValues: dayValues,
            matrixCells: matrixCells,
            bestBubble: bestBubble,
            totalPosts: posts.count,
            avgEngagementPerPost: muGlobal
        )
    }

    /// 收缩均值（经验 Bayes 风格）：μ̂ = (n/(n+k))·μ + (k/(n+k))·μ_global
    /// 小样本桶强烈依赖账号基线，样本越多越信任自身均值。确定性纯函数。
    static func shrunkMean(n: Int, sum: Double, muGlobal: Double) -> Double {
        let nn = Double(n)
        let mu = n > 0 ? sum / nn : 0
        return (nn / (nn + shrinkK)) * mu + (shrinkK / (nn + shrinkK)) * muGlobal
    }

    /// bootstrap 重采样：500 次有放回采样 → 重新聚合 → 收缩 → 统计目标窗口成为最佳的次数占比。
    /// 纯函数（注入 RNG），确定性可测。
    func bootstrapProbability(
        posts: [MediaPost],
        muGlobal: Double,
        targetStart: Int,
        using rng: inout SeededRandom
    ) -> Double {
        let count = posts.count
        guard count > 1 else { return 1.0 }
        var wins = 0
        for _ in 0..<Self.bootstrapSamples {
            // 有放回重采样
            var sampleCount = [Int](repeating: 0, count: 24)
            var sampleSum = [Double](repeating: 0, count: 24)
            for _ in 0..<count {
                let post = posts[rng.int(in: 0...(count - 1))]
                let hr = calendar.component(.hour, from: post.date)
                sampleCount[hr] += 1
                sampleSum[hr] += Double(post.likes + post.comments)
            }
            // 收缩 + 找最佳窗口
            var best = 0
            var bestMu = -Double.greatestFiniteMagnitude
            for h in 0..<24 {
                var n = 0, s = 0.0
                for d in 0..<Self.windowHours {
                    let hh = (h + d) % 24
                    n += sampleCount[hh]; s += sampleSum[hh]
                }
                let nn = Double(n)
                let mu = n > 0 ? s / nn : 0
                let muHat = (nn / (nn + Self.shrinkK)) * mu + (Self.shrinkK / (nn + Self.shrinkK)) * muGlobal
                if muHat > bestMu { bestMu = muHat; best = h }
            }
            if best == targetStart { wins += 1 }
        }
        return Double(wins) / Double(Self.bootstrapSamples)
    }

    private func emptyResult() -> BestPostingTimeResult {
        let recommendation = PostingTimeRecommendation(
            weekday: 1, startHour: 19, endHour: 21,
            score: 0, expectedEngagement: 0, liftVsAverage: 0,
            probabilityOfBeingBest: 0, sampleCount: 0)
        return BestPostingTimeResult(
            recommendation: recommendation,
            confidence: .low,
            accountAverageEngagement: 0,
            hourValues: [Double](repeating: 0, count: 24),
            dayValues: [Double](repeating: 0, count: 7),
            matrixCells: [],
            bestBubble: nil,
            totalPosts: 0,
            avgEngagementPerPost: 0
        )
    }
}
