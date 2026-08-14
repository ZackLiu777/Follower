//
//  CardGenerator.swift
//  Follower
//
//  卡片生成器 — 从 TemplateEngine 候选按机会分排序，分组为主列表与折叠区。
//  纯函数，Sendable，确定性。删除「每类 2 张」硬上限：
//  全部触发的模板按机会分降序，前 6 条为主列表，其余进折叠区。
//

import Foundation

// MARK: - GeneratedDecisions

/// 生成结果 — 主列表 + 折叠区
struct GeneratedDecisions: Sendable {
    /// 主列表（机会分前 6）
    let topSuggestions: [ActionCard]
    /// 折叠区（其余全部）
    let moreSuggestions: [ActionCard]

    /// 全部建议（按机会分降序）
    var all: [ActionCard] { topSuggestions + moreSuggestions }
    var isEmpty: Bool { all.isEmpty }
}

/// 候选建议 — 模板 + 机会分 + 量化收益 + 置信度
struct TemplateCandidate: Sendable {
    let template: DecisionTemplate
    let score: Int
    let impact: CardImpact
    /// 低置信（数据信号不足的降级版本）
    let lowConfidence: Bool

    init(template: DecisionTemplate, score: Int, impact: CardImpact, lowConfidence: Bool = false) {
        self.template = template
        self.score = score
        self.impact = impact
        self.lowConfidence = lowConfidence
    }
}

// MARK: - CardGenerator

/// 卡片生成器 — 全部候选按机会分排序，精选相关性最优的 ≤4 条为主列表，
/// 其余全部进折叠区（建议库入口）。
struct CardGenerator: Sendable {

    /// 主列表精选上限（产品约束：一次性显示不超过 4 条）
    static let topLimit = 4

    /// 主入口：生成全部建议 → 按账号阶段动态加权 → 精选主列表 + 折叠区
    /// 精选规则（相关性最优）：
    ///   1. 状态感知加权 — 按账号阶段（增长/下滑/停滞/爆发）给对应模板加分，
    ///      让不同数据状态产生不同精选组合
    ///   2. 强信号（非估算）优先
    ///   3. 类别去重 — 同一类别最多 1 条进精选，保证 4 条覆盖不同维度
    ///   4. 按机会分降序
    /// - Returns: 精选主列表（≤4 条，类别互不重复）+ 折叠区（其余全部）
    static func generate(scores: GrowthScores, features: GrowthFeatures) -> GeneratedDecisions {
        let candidates = TemplateEngine.candidates(features: features, scores: scores)
        let weighted = applyPhaseWeighting(candidates: candidates, phase: features.context.phase)
            .sorted { $0.score > $1.score }

        let selected = selectTop(candidates: weighted, limit: topLimit)
        let selectedIDs = Set(selected.map(\.template.id))
        let rest = weighted.filter { !selectedIDs.contains($0.template.id) }

        let cards = selected.enumerated().map { index, candidate in
            ActionCard(
                id: candidate.template.id,
                template: candidate.template,
                priority: index,
                impact: candidate.impact,
                lowConfidence: candidate.lowConfidence
            )
        }
        let more = rest.enumerated().map { index, candidate in
            ActionCard(
                id: candidate.template.id,
                template: candidate.template,
                priority: index,
                impact: candidate.impact,
                lowConfidence: candidate.lowConfidence
            )
        }
        print("[CardGenerator] phase: \(features.context.phase) | selected \(cards.count) + more \(more.count)")
        for c in cards {
            print("  [top] \(c.template.id) | lowConf: \(c.lowConfidence) | impact: +\(c.impact.followerGain)fans/+\(c.impact.viewsGain)views")
        }
        return GeneratedDecisions(topSuggestions: cards, moreSuggestions: more)
    }

    // MARK: - 状态感知加权

    /// 各阶段模板加权表 — 模板 id → 加分
    /// 让反映当前数据状态的模板在精选排序中胜出（不同数据 → 不同决策）
    static func phaseWeights(for phase: AccountPhase) -> [String: Int] {
        switch phase {
        case .growing:
            return [
                "boostTopType": 15, "replicateViral": 15, "viralFollowUp": 15,
                "topFansEngage": 10, "guideComments": 10,
                "reuseViral": 8, "seriesContent": 5,
            ]
        case .declining:
            return [
                "churnWarning": 25, "rescueDecliningType": 20, "engagementDecline": 20,
                "reachDecline": 15, "typeTrendWarning": 15, "growthSlowdown": 15,
                "conversionBoost": 10, "churnPeakDay": 10, "reduceFrequency": 8,
            ]
        case .stagnant:
            return [
                "increaseFrequency": 20, "monthlyPlan": 15,
                "seriesContent": 15, "inactiveWakeup": 10,
                "growthTarget": 8, "diversifyTypes": 8, "guideComments": 5,
            ]
        case .viral:
            return [
                "viralFollowUp": 25, "replicateViral": 20, "boostTopType": 15,
                "reuseViral": 15, "guideComments": 10, "topFansEngage": 10,
                "inactiveWakeup": 5,
            ]
        }
    }

    /// 应用阶段加权 — 加权后的候选（新增 TemplateCandidate）
    static func applyPhaseWeighting(candidates: [TemplateCandidate], phase: AccountPhase) -> [TemplateCandidate] {
        let weights = phaseWeights(for: phase)
        return candidates.map { candidate in
            let bonus = weights[candidate.template.id] ?? 0
            return TemplateCandidate(
                template: candidate.template,
                score: candidate.score + bonus,
                impact: candidate.impact,
                lowConfidence: candidate.lowConfidence
            )
        }
    }

    /// 精选算法：强信号优先 + 类别去重 + 机会分降序
    static func selectTop(candidates: [TemplateCandidate], limit: Int) -> [TemplateCandidate] {
        let sorted = candidates.sorted { $0.score > $1.score }
        var result: [TemplateCandidate] = []
        var usedTypes = Set<CardType>()

        func fill(highConfidenceOnly: Bool) {
            for c in sorted where c.lowConfidence != highConfidenceOnly {
                guard result.count < limit else { return }
                if usedTypes.contains(c.template.type) { continue }
                usedTypes.insert(c.template.type)
                result.append(c)
            }
        }

        fill(highConfidenceOnly: true)  // 先强信号
        fill(highConfidenceOnly: false) // 不足再弱信号补位
        return result
    }
}
