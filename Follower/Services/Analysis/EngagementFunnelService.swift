//
//  EngagementFunnelService.swift
//  Follower
//
//  Premium: 互动漏斗（Phi+）— 浏览 → 互动 → 涨粉 转化诊断。
//  纯函数、确定性：
//  - 三个环节转化率（快照日增量：浏览 / 互动 / 粉丝）
//  - 瓶颈诊断：相对最弱环节
//  - 量化机会：薄弱环节提升 10% 对应的预计月涨粉
//

import Foundation

// MARK: - 结果模型

/// 漏斗诊断结果
struct EngagementFunnelResult: Sendable {
    /// 浏览→互动 转化率（互动/浏览）
    let viewToEngagement: Double
    /// 互动→涨粉 转化率（涨粉/互动）
    let engagementToFollower: Double
    /// 浏览→涨粉 整体转化率（涨粉/浏览）
    let viewToFollower: Double
    /// 各环节相对强度（1.0 = 与整体持平，>1 强，<1 弱）
    let engagementStage: Double
    let followerStage: Double
    /// 瓶颈环节（view→互动 或 互动→涨粉）
    enum Bottleneck: String, Sendable {
        case engagement, conversion, none
    }
    let bottleneck: Bottleneck
    /// 量化机会：最弱环节提升 10% 的预计月涨粉（整数）
    let opportunityFollowers: Int
    /// 参与统计的涨粉 / 互动 / 浏览
    let followersDelta: Double
    let engagementDelta: Double
    let viewsDelta: Double
}

// MARK: - Service

/// 互动漏斗服务 — 确定性纯计算（快照日增量）
final class EngagementFunnelService: Sendable {

    /// 薄弱环节提升幅度（诊断建议的改进目标）
    static let improvementRate = 0.10

    func analyze(snapshots: [Snapshot]) async -> EngagementFunnelResult {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard sorted.count >= 2 else { return emptyResult() }

        // 全窗口正向增量（只计增长侧，与转化率口径一致）
        var f = 0.0, e = 0.0, v = 0.0
        for i in 1..<sorted.count {
            f += max(0, Double(sorted[i].followersCount - sorted[i - 1].followersCount))
            e += max(0, Double((sorted[i].totalLikes + sorted[i].totalComments)
                               - (sorted[i - 1].totalLikes + sorted[i - 1].totalComments)))
            v += max(0, Double(sorted[i].totalViews - sorted[i - 1].totalViews))
        }
        let viewToEng = v > 0 ? e / v : 0
        let engToFollower = e > 0 ? f / e : 0
        let viewToFollower = v > 0 ? f / v : 0

        // 环节相对强度：viewToFollower = viewToEng × engToFollower
        // 环节分解：整体转化率 vs 各环节（对整体取几何意义下的贡献）
        let overall = viewToFollower
        let engagementStage = overall > 0 && viewToEng > 0 ? viewToEng / overall : 0
        let followerStage = overall > 0 && engToFollower > 0 ? engToFollower / overall : 0

        // 瓶颈：环节相对强度更低者（同分 → none）
        let bottleneck: EngagementFunnelResult.Bottleneck
        if viewToEng > 0 && engToFollower > 0 {
            if engagementStage < followerStage { bottleneck = .engagement }
            else if followerStage < engagementStage { bottleneck = .conversion }
            else { bottleneck = .none }
        } else {
            bottleneck = .none
        }

        // 量化机会：最弱环节提升 10% → 粉丝增量
        let opportunity: Double
        switch bottleneck {
        case .engagement:
            // 互动 +10% → 涨粉 = Δeng × 0.1 × engToFollower
            opportunity = e * Self.improvementRate * engToFollower
        case .conversion:
            // 转化 +10% → 涨粉 = Δeng × engToFollower × 0.1
            opportunity = e * engToFollower * Self.improvementRate
        case .none:
            opportunity = 0
        }

        return EngagementFunnelResult(
            viewToEngagement: viewToEng,
            engagementToFollower: engToFollower,
            viewToFollower: viewToFollower,
            engagementStage: engagementStage,
            followerStage: followerStage,
            bottleneck: bottleneck,
            opportunityFollowers: Int(opportunity.rounded()),
            followersDelta: f,
            engagementDelta: e,
            viewsDelta: v
        )
    }

    private func emptyResult() -> EngagementFunnelResult {
        EngagementFunnelResult(
            viewToEngagement: 0, engagementToFollower: 0, viewToFollower: 0,
            engagementStage: 0, followerStage: 0,
            bottleneck: .none, opportunityFollowers: 0,
            followersDelta: 0, engagementDelta: 0, viewsDelta: 0
        )
    }
}
