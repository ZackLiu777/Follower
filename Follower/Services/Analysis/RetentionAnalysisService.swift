//
//  RetentionAnalysisService.swift
//  Follower
//
//  Gamma: 留存/流失分析（Premium）。基于 Snapshot 粉丝数变化。

import Foundation

/// 留存/流失分析结果：净增长率 / 日均变化 / 是否流失 / 流失风险等级
struct RetentionResult: Sendable {
    let netGrowthRate: Double        // 净增长率（正=增长，负=流失）
    let avgDailyChange: Double
    let isChurning: Bool             // 连续多天净减少
    let churnRiskLevel: String       // "None" / "Low" / "Medium" / "High"
    let startFollowers: Int
    let endFollowers: Int
}

/// 留存/流失分析服务协议（Premium）
protocol RetentionAnalysisServiceProtocol: Sendable {
    /// 分析 Snapshot 序列的留存/流失情况
    func analyze(snapshots: [Snapshot]) async -> RetentionResult
    /// 根据连续下降天数返回流失风险等级
    func churnRisk(consecutiveNegativeDays: Int) -> String
}

/// 留存/流失分析服务实现：检测连续负增长，评估流失风险
final class RetentionAnalysisService: RetentionAnalysisServiceProtocol {

    /// 基于 Snapshot 序列计算净增长率、日均变化和连续下降天数
    func analyze(snapshots: [Snapshot]) async -> RetentionResult {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return RetentionResult(netGrowthRate: 0, avgDailyChange: 0, isChurning: false, churnRiskLevel: "None", startFollowers: 0, endFollowers: 0)
        }

        let startFollowers = first.followersCount
        let endFollowers = last.followersCount
        let totalChange = Double(endFollowers - startFollowers)
        let netGrowthRate = startFollowers > 0 ? totalChange / Double(startFollowers) : 0
        let avgDailyChange = Double(sorted.count) > 1 ? totalChange / Double(sorted.count - 1) : 0

        var consecutiveNegative = 0
        var maxConsecutiveNegative = 0
        for i in 1..<sorted.count {
            if sorted[i].followersCount < sorted[i-1].followersCount {
                consecutiveNegative += 1
                maxConsecutiveNegative = max(maxConsecutiveNegative, consecutiveNegative)
            } else {
                consecutiveNegative = 0
            }
        }

        let isChurning = maxConsecutiveNegative >= 3
        let churnRiskLevel = churnRisk(consecutiveNegativeDays: maxConsecutiveNegative)

        return RetentionResult(
            netGrowthRate: netGrowthRate,
            avgDailyChange: avgDailyChange,
            isChurning: isChurning,
            churnRiskLevel: churnRiskLevel,
            startFollowers: startFollowers,
            endFollowers: endFollowers
        )
    }

    /// 将连续下降天数映射为流失风险等级：None / Low / Medium / High
    func churnRisk(consecutiveNegativeDays: Int) -> String {
        switch consecutiveNegativeDays {
        case 0..<2:  return "None"
        case 2..<5:  return "Low"
        case 5..<10: return "Medium"
        default:     return "High"
        }
    }
}
