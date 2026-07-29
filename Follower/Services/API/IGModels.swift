//
//  IGModels.swift
//  Follower
//
//  Instagram Graph API 原始响应模型（Codable，与 API JSON 1:1 匹配）。
//  仅用于 API 层反序列化，不暴露到 Domain / View 层。
//

import Foundation

// MARK: - IGUser

/// GET /me 返回的用户资料
struct IGUser: Codable {
    let id: String
    let username: String
    let name: String?
    let followersCount: Int?
    let followsCount: Int?
    let mediaCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case followersCount = "followers_count"
        case followsCount = "follows_count"
        case mediaCount = "media_count"
    }
}

// MARK: - IGInsightValue

/// GET /me/insights 返回的单个指标值
struct IGInsightValue: Codable {
    let name: String?
    let period: String?
    /// 时间序列数据点
    let values: [IGInsightDataPoint]?
    /// 标量值（breakdown 格式的指标，如 audience_country）
    let totalValue: IGInsightTotalValue?

    enum CodingKeys: String, CodingKey {
        case name, period, values
        case totalValue = "total_value"
    }
}

/// 标量值的 breakdown 结构
struct IGInsightTotalValue: Codable {
    let breakdowns: [IGInsightBreakdown]?
}

/// 单个 breakdown 条目：维度值 + 数值
struct IGInsightBreakdown: Codable {
    let dimensionValues: [String]?
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case dimensionValues = "dimension_values"
        case value
    }
}

/// 时间序列中的单个数据点
struct IGInsightDataPoint: Codable {
    let value: Double?
    let endTime: String?

    enum CodingKeys: String, CodingKey {
        case value
        case endTime = "end_time"
    }
}

/// Insights 响应
struct IGInsightsResponse: Codable {
    let data: [IGInsightValue]?
}

// MARK: - IGMedia

/// GET /me/media 返回的单条媒体
struct IGMedia: Codable {
    let id: String
    let caption: String?
    let mediaType: String?
    let permalink: String?
    let timestamp: String?
    let likeCount: Int?
    let commentsCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, caption, permalink, timestamp
        case mediaType = "media_type"
        case likeCount = "like_count"
        case commentsCount = "comments_count"
    }
}

/// GET /me/media 的分页响应
struct IGMediaResponse: Codable {
    let data: [IGMedia]?
}
