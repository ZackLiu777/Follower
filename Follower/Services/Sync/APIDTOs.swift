//
//  APIDTOs.swift
//  Follower
//
//  外部 API 返回数据的 DTO 定义。
//  DTO 仅用于网络层与 Ingestion 层之间的数据传递。
//  不得直接暴露给 Domain Models 或 View。
//

import Foundation

// MARK: - API Patterns

/// API 返回的粉丝数、关注数等基础指标
struct APIProfileResponse: Codable {
    let username: String
    let displayName: String
    let followersCount: Int
    let followingCount: Int
    let mediaCount: Int
    let totalLikes: Int
    let totalComments: Int
    let totalShares: Int
    let totalViews: Int
    let engagementRate: Double
    let fetchedAt: Date
}

/// API 返回的互动统计
struct APIEngagementResponse: Codable {
    let username: String
    let likes: Int
    let comments: Int
    let shares: Int
    let views: Int
    let period: String // "day", "week", "month"
    let fetchedAt: Date
}

/// API 返回的历史趋势数据点
struct APITrendDataPoint: Codable {
    let date: Date
    let followersCount: Int
    let followingCount: Int
    let mediaCount: Int
    let engagementRate: Double
    let totalViews: Int
    /// 互动明细（点赞/评论/分享）。真实 API 不返回这些日频指标 → nil；
    /// Mock 数据源提供 → 有值。Optional 保证旧 Event payload（无这些 key）解码不失败。
    let likesCount: Int?
    let commentsCount: Int?
    let sharesCount: Int?
}

/// API 返回的趋势时间序列
struct APITrendResponse: Codable {
    let username: String
    let dataPoints: [APITrendDataPoint]
    let period: String
}

// MARK: - Sync Result

/// 同步操作结果：记录创建的 Event 数、更新的 Snapshot/Metric 数及错误
struct SyncResult {
    let accountId: Int64
    let eventsCreated: Int
    let snapshotsUpdated: Int
    let metricsUpdated: Int
    let errors: [Error]

    var isSuccess: Bool { errors.isEmpty }
}
