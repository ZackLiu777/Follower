//
//  CardGenerator.swift
//  Follower
//
//  卡片生成器 — 将 GrowthScores 和 GrowthFeatures 转化为 ActionCard 数组。
//  纯函数，Sendable，无状态。基于规则引擎生成四种类型的行动卡片。

import Foundation

// MARK: - CardGenerator

/// 卡片生成器 — 根据评分结果和原始特征，按规则生成有序的 ActionCard 数组。
///
/// 生成规则（按优先级）：
/// 1. 最高分内容类型 → Primary Action Card（score > 0.5）
/// 2. 疲劳检测 → Alert Card（每种疲劳类型一张）
/// 3. 粉丝不活跃 → Recovery Card（recoveryNeeded > 0.5）
/// 4. 通用洞察 → Insight Card（始终生成）
///
/// 最终按 priority 升序排列
struct CardGenerator: Sendable {

    // MARK: - Main Entry Point

    /// 主入口：根据评分和特征生成全部卡片
    /// - Parameters:
    ///   - scores: ScoringEngine 输出的评分结果
    ///   - features: FeatureExtractor 输出的原始特征
    /// - Returns: 按 priority 升序排列的 ActionCard 数组
    static func generate(scores: GrowthScores, features: GrowthFeatures) -> [ActionCard] {
        var cards: [ActionCard] = []

        // Rule 1: 最高分内容类型 → Primary Action Card
        if let top = scores.contentScores.first, top.1 > 0.5,
           let stats = features.contentPerformance[top.0] {
            cards.append(primaryCard(for: top.0, score: top.1, stats: stats))
        }

        // Rule 2: 疲劳检测 → Alert Card（每种疲劳类型生成一张）
        for type in scores.fatiguedTypes {
            cards.append(fatigueCard(for: type))
        }

        // Rule 3: 粉丝不活跃 → Recovery Card
        if scores.recoveryNeeded > 0.5 {
            cards.append(recoveryCard(health: features.followerHealth))
        }

        // Rule 4: 通用洞察 → Insight Card
        if let insight = insightCard(scores: scores, features: features) {
            cards.append(insight)
        }

        // 按 priority 升序排列（越小越靠前）
        return cards.sorted { $0.priority < $1.priority }
    }

    // MARK: - Card Builders

    /// 生成 Primary Action Card — 推荐最高 ROI 内容操作
    /// - Parameters:
    ///   - type: 最优内容类型
    ///   - score: 该类型的评分
    ///   - stats: 该类型的表现统计
    /// - Returns: Primary 类型 ActionCard
    private static func primaryCard(for type: ContentType, score: Double, stats: ContentStats) -> ActionCard {
        let typeName = "\(type)".capitalized
        return ActionCard(
            id: UUID().uuidString,
            type: .primary,
            icon: "flame.fill",
            title: loc(L10n.Decisions.boostGrowth),
            actions: [
                String(format: loc(L10n.Decisions.actionPostType), typeName, "highest"),
                loc(L10n.Decisions.actionEngageFollowers),
                loc(L10n.Decisions.actionReplyComments)
            ],
            reason: String(format: loc(L10n.Decisions.reasonReelOutperform), typeName, stats.avgEngagement * 100 / 1.3),
            impact: loc(L10n.Decisions.impactBoost),
            priority: 0
        )
    }

    /// 生成 Alert Card — 内容疲劳警告
    /// - Parameter type: 疲劳的内容类型
    /// - Returns: Alert 类型 ActionCard
    private static func fatigueCard(for type: ContentType) -> ActionCard {
        let typeName = "\(type)".capitalized
        return ActionCard(
            id: UUID().uuidString,
            type: .alert,
            icon: "exclamationmark.triangle.fill",
            title: loc(L10n.Decisions.contentFatigue),
            actions: [String(format: loc(L10n.Decisions.actionReducePosts), typeName.lowercased())],
            reason: String(format: loc(L10n.Decisions.reasonPerformanceDeclining), typeName),
            impact: nil,
            priority: 1
        )
    }

    /// 生成 Recovery Card — 粉丝重新激活建议
    /// - Parameter health: 粉丝健康度快照
    /// - Returns: Recovery 类型 ActionCard
    private static func recoveryCard(health: FollowerHealth) -> ActionCard {
        let pct = Int((1.0 - health.activeRatio) * 100)
        return ActionCard(
            id: UUID().uuidString,
            type: .recovery,
            icon: "arrow.up.heart.fill",
            title: loc(L10n.Decisions.engagementRecovery),
            actions: [
                loc(L10n.Decisions.actionDMSupporters),
                loc(L10n.Decisions.actionReengage)
            ],
            reason: String(format: loc(L10n.Decisions.reasonInactiveFollowers), pct),
            impact: loc(L10n.Decisions.impactRecovery),
            priority: 2
        )
    }

    /// 生成 Insight Card — 最佳发帖时间洞察
    /// - Parameters:
    ///   - scores: 评分结果（预留，后续可能用于条件判断）
    ///   - features: 特征数据，用于提取时间画像
    /// - Returns: Insight 类型 ActionCard，始终返回非 nil
    private static func insightCard(scores: GrowthScores, features: GrowthFeatures) -> ActionCard? {
        let bestHour = String(features.timingProfile.bestHours.split(separator: "–").first ?? "7 PM")
        // 将 bestDay 数字转换为星期名称
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayIndex = features.timingProfile.bestDay - 1  // bestDay: 1=Sun
        let dayName = (0..<7).contains(dayIndex) ? dayNames[dayIndex] : "Wed"
        return ActionCard(
            id: UUID().uuidString,
            type: .insight,
            icon: "lightbulb.fill",
            title: loc(L10n.Decisions.bestPostingTime),
            actions: [String(format: loc(L10n.Decisions.actionSchedule), dayName, bestHour)],
            reason: String(format: loc(L10n.Decisions.reasonAudienceActive), dayName, features.timingProfile.bestHours),
            impact: loc(L10n.Decisions.impactEngagement),
            priority: 3
        )
    }
}
