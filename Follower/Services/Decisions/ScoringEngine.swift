//
//  ScoringEngine.swift
//  Follower
//
//  评分引擎 — 将 GrowthFeatures 转化为 GrowthScores。
//  纯函数，Sendable，无状态。所有评分逻辑为确定性计算，便于单元测试。

import Foundation

// MARK: - ScoringEngine

/// 评分引擎 — 负责将提取的特征（GrowthFeatures）转化为
/// 可用于生成 ActionCard 的评分结果（GrowthScores）
struct ScoringEngine: Sendable {

    // MARK: - Content Type Scoring

    /// 内容类型评分公式（相对排名，无绝对常量假设）：
    ///   relEng × 0.5 + relGrowth × 0.3 + (1 − fatigue) × 0.2
    /// 其中：
    ///   relEng = 本类型平均互动 ÷ 全部类型最大平均互动（0~1）
    ///   relGrowth = (clamp(growthRate, −1, 1) + 1) / 2（0~1）
    /// 结果天然位于 [0.0, 1.0]
    /// - Parameters:
    ///   - stats: 该内容类型的表现统计（真实数据）
    ///   - maxEngagement: 全部类型中的最大平均互动（相对基准）
    ///   - fatigue: 疲劳惩罚系数（来自 FatigueIndex.penalty）
    /// - Returns: 该内容类型的综合得分（0.0 ~ 1.0）
    static func scoreContentType(_ stats: ContentStats, maxEngagement: Double, fatigue: Double) -> Double {
        let relEng = maxEngagement > 0 ? min(1.0, stats.avgEngagement / maxEngagement) : 0.0
        let relGrowth = (min(1.0, max(-1.0, stats.growthRate)) + 1.0) / 2.0
        let relFatigue = min(1.0, max(0.0, fatigue))
        return relEng * 0.5 + relGrowth * 0.3 + (1.0 - relFatigue) * 0.2
    }

    // MARK: - Growth Health Scoring

    /// 粉丝增长健康评分：
    ///   growthRate(0~1) * 0.4 + activeRatio * 0.6
    /// 结果 clamped 到 [0.0, 1.0]
    /// - Parameter health: 粉丝健康度快照
    /// - Returns: 增长健康得分（越高越健康）
    static func scoreGrowthHealth(_ health: FollowerHealth) -> Double {
        let growth = min(max(health.followerGrowth7d / 100.0, 0), 1) * 0.4
        let active = health.activeRatio * 0.6
        return min(1.0, max(0.0, growth + active))
    }

    // MARK: - Recovery Scoring

    /// 恢复需求评分（越高越需要执行粉丝恢复操作）：
    ///   当 activeRatio < 0.5 时，(0.5 - activeRatio) * 2.0
    ///   当 activeRatio >= 0.5 时，返回 0（无需恢复）
    /// - Parameter health: 粉丝健康度快照
    /// - Returns: 恢复需求得分（0.0 ~ 1.0）
    static func scoreRecoveryNeeded(_ health: FollowerHealth) -> Double {
        guard health.activeRatio < 0.5 else { return 0 }
        return min(1.0, max(0.0, (0.5 - health.activeRatio) * 2.0))
    }

    // MARK: - Main Entry Point

    /// 综合评分主入口 — 对各维度逐一评分后汇总为 GrowthScores
    /// - Parameter features: 特征提取结果
    /// - Returns: 汇总评分结果，contentScores 按分数降序排列
    static func score(_ features: GrowthFeatures) -> GrowthScores {
        // 各内容类型评分，按分数降序；相对基准 = 全部类型最大平均互动
        let maxEng = features.contentPerformance.values.map(\.avgEngagement).max() ?? 0
        let contentResults = features.contentPerformance.map { (type, stats) in
            let fatigue = features.fatigueIndices[type]?.penalty ?? 0
            return (type, scoreContentType(stats, maxEngagement: maxEng, fatigue: fatigue))
        }.sorted { $0.1 > $1.1 }

        // 收集疲劳的内容类型
        let fatigued = features.fatigueIndices.compactMap { (type, idx) in
            idx.isFatigued ? type : nil
        }

        return GrowthScores(
            contentScores: contentResults,
            growthHealth: scoreGrowthHealth(features.followerHealth),
            recoveryNeeded: scoreRecoveryNeeded(features.followerHealth),
            fatiguedTypes: fatigued
        )
    }
}
