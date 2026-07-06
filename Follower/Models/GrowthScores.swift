//
//  GrowthScores.swift
//  Follower
//
//  ScoringEngine 的输出 — 汇总各维度评分结果，供 CardGenerator 生成 ActionCard。

import Foundation

// MARK: - GrowthScores

/// 评分结果汇总 — ScoringEngine 将 GrowthFeatures 转化为 GrowthScores，
/// 再由 CardGenerator 转化为 ActionCard 数组
struct GrowthScores: Sendable {
    /// 内容类型得分列表，按分数降序排列（最高分在前）
    let contentScores: [(ContentType, Double)]
    /// 粉丝增长健康得分（0.0 ~ 1.0，越高越健康）
    let growthHealth: Double
    /// 恢复需求得分（0.0 ~ 1.0，越高越需要恢复操作）
    let recoveryNeeded: Double
    /// 检测到疲劳的内容类型列表
    let fatiguedTypes: [ContentType]

    /// 最高分内容类型（contentScores 非空时返回第一个元素）
    var topContentType: ContentType? { contentScores.first?.0 }
    /// 最高得分值
    var topScore: Double { contentScores.first?.1 ?? 0 }
}

// MARK: - Mock Data (Preview)

extension GrowthScores {
    /// 模拟评分数据，供 Preview 和开发调试使用
    static func mock() -> GrowthScores {
        GrowthScores(
            contentScores: [(.reel, 0.87), (.carousel, 0.52), (.photo, 0.31)],
            growthHealth: 0.68,
            recoveryNeeded: 0.64,
            fatiguedTypes: [.carousel]
        )
    }
}
