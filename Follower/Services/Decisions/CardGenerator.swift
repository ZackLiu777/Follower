//
//  CardGenerator.swift
//  Follower
//
//  卡片生成器 — 将 GrowthScores 和 GrowthFeatures 转化为 ActionCard 数组。
//  纯函数，Sendable，无状态。基于规则引擎生成四种类型的行动卡片。
//  卡片模板参数存储在 ActionCardTemplate 中，本地化字符串由 View 层实时渲染。

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

        // Rule 1: 最高分内容类型 → Primary Action Card（阈值极低确保总是触发）
        if let top = scores.contentScores.first, top.1 > 0.01,
           let stats = features.contentPerformance[top.0] {
            let ctx: CardContext = stats.growthRate > 0.05 ? .growing
                : stats.growthRate < -0.03 ? .declining : .stable
            cards.append(primaryCard(for: top.0, stats: stats, context: ctx))
        }

        // Rule 2: 疲劳检测 → 最多一张 Alert Card（合并所有疲劳类型）
        if let firstFatigued = scores.fatiguedTypes.first {
            let maxPenalty = scores.fatiguedTypes.compactMap { features.fatigueIndices[$0]?.penalty }.max() ?? 0.2
            cards.append(fatigueCard(for: firstFatigued, penalty: maxPenalty))
        }

        // Rule 3: 粉丝不活跃 → Recovery Card（阈值极低确保总是触发）
        if scores.recoveryNeeded > 0.01 {
            cards.append(recoveryCard(health: features.followerHealth))
        }

        // Rule 4: 通用洞察 → Insight Card
        if let insight = insightCard(features: features) {
            cards.append(insight)
        }

        // 确保最少 4 张卡片 — 缺失的类型用变体补充，避免重复
        let missing = 4 - cards.count
        if missing > 0 {
            let variants = fallbackCards(features: features, scores: scores, count: missing, existing: cards)
            cards.append(contentsOf: variants)
        }

        let sorted = cards.sorted { $0.priority < $1.priority }
        print("[CardGenerator] generated \(sorted.count) cards:")
        for c in sorted {
            print("  [\(c.priority)] \(c.type) | \(c.template.displayTitle) | actions: \(c.template.displayActions.count)")
        }
        return sorted
    }

    /// 生成变体卡片填补空缺 — 每张不同 variation + bestDay，并去重
    private static func fallbackCards(features: GrowthFeatures, scores: GrowthScores,
                                       count: Int, existing: [ActionCard]) -> [ActionCard] {
        var result: [ActionCard] = []
        let hour = String(features.timingProfile.bestHours.split(separator: "–").first ?? "19:00")
        let baseDay = features.timingProfile.bestDay
        // 收集已有卡片中已使用的 variation
        let usedVariations = Set(existing.compactMap { card in
            if case .insight(_, _, let v) = card.template { return v }
            return nil
        })
        var vi = 1
        for i in 0..<count {
            while usedVariations.contains(vi) { vi = (vi + 1) % 4 }
            let v = vi; vi = (vi + 1) % 4
            // 每张 fallback 偏移不同天数，确保行动建议不同
            let day = ((baseDay - 1 + (i + 1) * 2) % 7) + 1
            result.append(ActionCard(id: UUID().uuidString, type: .insight,
                icon: "lightbulb.fill",
                template: .insight(bestDay: day, bestHour: hour, variation: v),
                priority: 10 + i))
        }
        return result
    }

    // MARK: - Card Builders

    private static func primaryCard(for type: ContentType, stats: ContentStats, context: CardContext) -> ActionCard {
        let x = round((stats.avgEngagement * 100 / 1.3) * 10) / 10
        return ActionCard(id: UUID().uuidString, type: .primary, icon: "flame.fill",
            template: .primary(contentType: type, outperformanceX: x, context: context), priority: 0)
    }

    private static func fatigueCard(for type: ContentType, penalty: Double) -> ActionCard {
        ActionCard(id: UUID().uuidString, type: .alert, icon: "exclamationmark.triangle.fill",
            template: .alert(fatiguedType: type, penalty: penalty), priority: 1)
    }

    private static func recoveryCard(health: FollowerHealth) -> ActionCard {
        let pct = Int((1.0 - health.activeRatio) * 100)
        let ctx: CardContext = pct > 70 ? .severe : .declining
        return ActionCard(id: UUID().uuidString, type: .recovery, icon: "arrow.up.heart.fill",
            template: .recovery(inactivePct: pct, context: ctx), priority: 2)
    }

    private static func insightCard(features: GrowthFeatures) -> ActionCard? {
        let bestHour = String(features.timingProfile.bestHours.split(separator: "–").first ?? "19:00")
        return ActionCard(id: UUID().uuidString, type: .insight, icon: "lightbulb.fill",
            template: .insight(bestDay: features.timingProfile.bestDay, bestHour: bestHour), priority: 3)
    }
}
