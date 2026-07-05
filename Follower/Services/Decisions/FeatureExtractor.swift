//
//  FeatureExtractor.swift
//  Follower
//
//  特征提取器 — 从原始 Snapshot / Metric 数据中提取 GrowthFeatures。
//  纯函数，Sendable，无状态。Alpha 阶段部分维度使用 mock 数据，
//  后续接入真实帖子数据后替换。

import Foundation

// MARK: - FeatureExtractor

/// 特征提取器 — 将底层持久化数据（Snapshot / Metric）转化为
/// Growth Decision Engine 可直接评分的 GrowthFeatures 结构
struct FeatureExtractor: Sendable {

    // MARK: - FollowerHealth

    /// 从 Snapshot 序列中提取 FollowerHealth
    /// - Parameters:
    ///   - snapshots: 历史快照数组（按 observedAt 排序后取首尾计算增长率）
    ///   - followers: 当前粉丝总数
    /// - Returns: 粉丝健康度快照
    static func extractHealth(snapshots: [Snapshot], followers: Int) -> FollowerHealth {
        guard !snapshots.isEmpty else {
            return FollowerHealth(
                activeFollowers: 0,
                inactiveFollowers: 0,
                totalFollowers: followers,
                followerGrowth7d: 0,
                followerGrowth30d: 0
            )
        }
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        let first = sorted.first!
        let last = sorted.last!
        // Alpha: 活跃/不活跃比例使用固定估算值（后续接入真实互动数据）
        let active = Int(Double(followers) * 0.18)
        let inactive = Int(Double(followers) * 0.62)
        return FollowerHealth(
            activeFollowers: active,
            inactiveFollowers: inactive,
            totalFollowers: followers,
            followerGrowth7d: Double(last.followersCount - first.followersCount),
            followerGrowth30d: Double(last.followersCount - first.followersCount) * 4.0
        )
    }

    // MARK: - ContentPerformance

    /// 从 Metric 序列中提取各内容类型表现统计
    /// - Parameter metrics: 分析指标数组
    /// - Returns: 以 ContentType 为 key 的 ContentStats 字典
    /// - Note: Alpha 阶段使用 mock 数据，后续接入真实帖子数据
    static func extractContentPerformance(metrics: [Metric]) -> [ContentType: ContentStats] {
        var result: [ContentType: ContentStats] = [:]
        for type in ContentType.allCases {
            // Alpha: Mock data — 后续接入真实帖子数据
            let stats = ContentStats(
                type: type,
                avgEngagement: type == .reel ? 0.042 : (type == .carousel ? 0.021 : 0.013),
                totalPosts: type == .reel ? 40 : (type == .carousel ? 55 : 70),
                recentPosts: type == .reel ? 3 : (type == .carousel ? 7 : 5),
                growthRate: type == .reel ? 0.12 : (type == .carousel ? -0.05 : 0.02)
            )
            result[type] = stats
        }
        return result
    }

    // MARK: - TimingProfile

    /// 提取发帖时间画像
    /// - Parameter metrics: 分析指标数组
    /// - Returns: 最佳/最差时段与最佳发帖日
    /// - Note: Alpha 阶段返回固定 mock 数据，后续接入真实互动时间分布
    static func extractTimingProfile(metrics: [Metric]) -> TimingProfile {
        // Alpha: Mock data — 后续接入真实互动时间分布分析
        TimingProfile(
            bestHours: "19:00–21:00",
            worstHours: "03:00–06:00",
            bestDay: 4  // Wednesday
        )
    }

    // MARK: - FatigueIndex

    /// 从内容表现数据提取各类型的疲劳检测指标
    /// - Parameter performance: 各内容类型的 ContentStats
    /// - Returns: 以 ContentType 为 key 的 FatigueIndex 字典
    static func extractFatigue(performance: [ContentType: ContentStats]) -> [ContentType: FatigueIndex] {
        var result: [ContentType: FatigueIndex] = [:]
        for (type, stats) in performance {
            let fatigue = FatigueIndex(
                contentType: type,
                posts7d: stats.recentPosts,
                engagementTrend: stats.growthRate
            )
            result[type] = fatigue
        }
        return result
    }
}
