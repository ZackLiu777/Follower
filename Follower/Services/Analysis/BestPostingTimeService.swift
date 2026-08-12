//
//  BestPostingTimeService.swift
//  Follower
//
//  Sigma: 最佳发帖时间服务（Premium）— 与互动热力图（Event+快照）数据源分离。
//  基于 MediaPost（真实帖子数据）按发布时间聚合互动表现：
//  哪个 (weekday, hour) 发布的帖子获得的互动（likes+comments）最多。
//

import Foundation

// MARK: - BestTimeBubbleCell

/// 气泡矩阵单元格：(weekday, 3 小时桶) 的平均互动与样本量。
/// 平均互动 = 该桶 likes+comments 总和 ÷ 帖子数；
/// 样本量用于视觉提示「单帖高互动」的误导风险。
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

/// 最佳发帖时间结果：小时/星期互动分布 + 气泡矩阵 + 最佳时段推荐
struct BestPostingTimeResult: Sendable {
    /// 每小时互动量（24 个，归一化峰值=1.0，索引 = hour 0-23）
    let hourValues: [Double]
    /// 每星期互动量（7 个，Sun-first 与 Calendar 一致，归一化）
    let dayValues: [Double]
    /// 7×8 气泡矩阵（7 天 × 每 3 小时桶，共 56 格，含空桶）
    let matrixCells: [BestTimeBubbleCell]
    /// 矩阵内最佳格（平均互动峰值）；无样本时 nil
    let bestBubble: BestTimeBubbleCell?
    /// 最佳发帖小时（0-23）
    let bestHour: Int
    /// 最佳发帖日（Calendar weekday 1=Sun...7=Sat）
    let bestDay: Int
    /// 最佳时段描述（如 "Wed 19:00"，数据层英文）
    let peakDescription: String
    /// 参与统计的帖子数
    let totalPosts: Int
    /// 平均每帖互动（likes + comments）
    let avgEngagementPerPost: Double

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

/// 最佳发帖时间服务：按帖子发布时间聚合互动量（likes + comments）。
/// 归一化规则与 EngagementHeatmapService 一致（最大值映射 1.0），
/// 确定性纯计算，便于测试。
final class BestPostingTimeService: BestPostingTimeServiceProtocol {

    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 1  // Sunday = 1
        return c
    }()

    func analyze(from posts: [MediaPost]) async -> BestPostingTimeResult {
        guard !posts.isEmpty else {
            return emptyResult()
        }

        // 每小时 / 每星期 / 气泡矩阵（weekday × 3 小时桶）互动量累计
        let bucketCount = 8
        var hourCounts = [Double](repeating: 0, count: 24)
        var dayCounts = [Double](repeating: 0, count: 7)
        var bucketTotals = [Double](repeating: 0, count: 7 * bucketCount)
        var bucketPosts = [Int](repeating: 0, count: 7 * bucketCount)

        for post in posts {
            let hr = calendar.component(.hour, from: post.date)
            let wd = calendar.component(.weekday, from: post.date)
            let engagement = Double(post.likes + post.comments)
            hourCounts[hr] += engagement
            dayCounts[wd - 1] += engagement
            let idx = (wd - 1) * bucketCount + hr / 3
            bucketTotals[idx] += engagement
            bucketPosts[idx] += 1
        }

        // 最佳时段：按互动量（非归一化值）取峰值
        let bestHour = hourCounts.indices.max(by: { hourCounts[$0] < hourCounts[$1] }) ?? 0
        let bestDay = dayCounts.indices.max(by: { dayCounts[$0] < dayCounts[$1] }) ?? 0

        // 归一化：最大值映射 1.0
        func normalized(_ counts: [Double]) -> [Double] {
            let peak = counts.max() ?? 1
            return counts.map { $0 / max(peak, 1) }
        }

        // 气泡矩阵：每桶平均互动（非总和，避免帖子数影响大小编码）
        var matrixCells: [BestTimeBubbleCell] = []
        for wd in 1...7 {
            for b in 0..<bucketCount {
                let idx = (wd - 1) * bucketCount + b
                let count = bucketPosts[idx]
                matrixCells.append(BestTimeBubbleCell(
                    weekday: wd,
                    hourBucket: b,
                    avgEngagement: count > 0 ? bucketTotals[idx] / Double(count) : 0,
                    postCount: count
                ))
            }
        }
        // 最佳格 = 平均互动峰值（有样本的格子）
        let bestBubble = matrixCells
            .filter { $0.postCount > 0 }
            .max(by: { $0.avgEngagement < $1.avgEngagement })

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = dayCounts.indices.contains(bestDay) ? dayNames[bestDay] : "?"
        let peakDesc = "\(dayName) \(String(format: "%02d:00", bestHour))"
        let avgEngagement = Double(posts.map { $0.likes + $0.comments }.reduce(0, +)) / Double(max(posts.count, 1))

        return BestPostingTimeResult(
            hourValues: normalized(hourCounts),
            dayValues: normalized(dayCounts),
            matrixCells: matrixCells,
            bestBubble: bestBubble,
            bestHour: bestHour,
            bestDay: bestDay + 1,  // dayCounts 索引 0=Sun → weekday 1=Sun
            peakDescription: peakDesc,
            totalPosts: posts.count,
            avgEngagementPerPost: avgEngagement
        )
    }

    private func emptyResult() -> BestPostingTimeResult {
        BestPostingTimeResult(
            hourValues: [Double](repeating: 0, count: 24),
            dayValues: [Double](repeating: 0, count: 7),
            matrixCells: [],
            bestBubble: nil,
            bestHour: 0,
            bestDay: 1,
            peakDescription: "",
            totalPosts: 0,
            avgEngagementPerPost: 0
        )
    }
}
