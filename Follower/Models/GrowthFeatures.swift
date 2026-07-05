//
//  GrowthFeatures.swift
//  Follower
//
//  特征提取结果的数据模型 — 定义内容表现、粉丝健康、发帖时间画像、
//  内容疲劳检测等所有可评分维度的聚合结构。

import Foundation

// MARK: - ContentType

/// 内容类型：Reel / 轮播图 / 单图
enum ContentType: String, Sendable, CaseIterable {
    /// 短视频 Reel — Instagram 当前最高 ROI 格式
    case reel
    /// 多图轮播 Carousel
    case carousel
    /// 单张图片 Photo
    case photo
}

// MARK: - ContentStats

/// 单种内容类型的表现统计数据
struct ContentStats: Sendable {
    /// 内容类型
    let type: ContentType
    /// 平均互动率（likes + comments + shares）/ impressions
    let avgEngagement: Double
    /// 历史帖子总数
    let totalPosts: Int
    /// 最近 7 天发帖数
    let recentPosts: Int
    /// 互动增长趋势（正数=上升，负数=下降）
    let growthRate: Double
}

// MARK: - FollowerHealth

/// 粉丝健康度快照
struct FollowerHealth: Sendable {
    /// 活跃粉丝数（近 30 天有互动）
    let activeFollowers: Int
    /// 不活跃粉丝数
    let inactiveFollowers: Int
    /// 粉丝总数
    let totalFollowers: Int
    /// 活跃粉丝占比（计算属性）
    var activeRatio: Double {
        totalFollowers > 0 ? Double(activeFollowers) / Double(totalFollowers) : 0
    }
    /// 近 7 天粉丝增长数
    let followerGrowth7d: Double
    /// 近 30 天粉丝增长数
    let followerGrowth30d: Double
}

// MARK: - TimingProfile

/// 发帖时间画像 — 最佳/最差发帖时段与日期
struct TimingProfile: Sendable {
    /// 最佳发帖时段，例如 "19:00–21:00"
    let bestHours: String
    /// 最差发帖时段，例如 "03:00–06:00"
    let worstHours: String
    /// 最佳发帖日（1=Sun, 2=Mon, ..., 7=Sat）
    let bestDay: Int
}

// MARK: - FatigueIndex

/// 内容疲劳检测指标 — 用于识别过度发布的内容类型
struct FatigueIndex: Sendable {
    /// 检测的内容类型
    let contentType: ContentType
    /// 最近 7 天发帖数
    let posts7d: Int
    /// 互动趋势（正=改善，负=恶化）
    let engagementTrend: Double
    /// 是否处于疲劳状态（7 天内发帖 > 5 次即为疲劳）
    var isFatigued: Bool { posts7d > 5 }
    /// 疲劳惩罚系数（疲劳时 0.3，否则 0.0）
    var penalty: Double { isFatigued ? 0.3 : 0.0 }
}

// MARK: - GrowthFeatures

/// 特征提取结果 — FeatureExtractor 的输出，
/// 聚合内容表现、粉丝健康、时间画像和疲劳检测等所有可评分维度
struct GrowthFeatures: Sendable {
    /// 各内容类型的表现统计（以 ContentType 为 key）
    let contentPerformance: [ContentType: ContentStats]
    /// 粉丝健康度快照
    let followerHealth: FollowerHealth
    /// 发帖时间画像
    let timingProfile: TimingProfile
    /// 各内容类型的疲劳检测指标（以 ContentType 为 key）
    let fatigueIndices: [ContentType: FatigueIndex]
}

// MARK: - Mock Data (Preview)

extension GrowthFeatures {
    /// 模拟特征数据，供 Preview 和开发调试使用
    static let mock: GrowthFeatures = {
        var perf: [ContentType: ContentStats] = [:]
        for type in ContentType.allCases {
            perf[type] = ContentStats(
                type: type,
                avgEngagement: type == .reel ? 0.042 : (type == .carousel ? 0.021 : 0.013),
                totalPosts: type == .reel ? 40 : (type == .carousel ? 55 : 70),
                recentPosts: type == .reel ? 3 : (type == .carousel ? 7 : 5),
                growthRate: type == .reel ? 0.12 : (type == .carousel ? -0.05 : 0.02)
            )
        }
        return GrowthFeatures(
            contentPerformance: perf,
            followerHealth: FollowerHealth(
                activeFollowers: 1800,
                inactiveFollowers: 6200,
                totalFollowers: 10000,
                followerGrowth7d: 85,
                followerGrowth30d: 320
            ),
            timingProfile: TimingProfile(
                bestHours: "19:00–21:00",
                worstHours: "03:00–06:00",
                bestDay: 4
            ),
            fatigueIndices: [
                .carousel: FatigueIndex(contentType: .carousel, posts7d: 7, engagementTrend: -0.28),
                .reel: FatigueIndex(contentType: .reel, posts7d: 3, engagementTrend: 0.12),
                .photo: FatigueIndex(contentType: .photo, posts7d: 5, engagementTrend: 0.02)
            ]
        )
    }()
}
