//
//  RetentionAnalysisService.swift
//  Follower
//
//  Gamma: 留存/流失分析（Premium）。基于 Snapshot 粉丝数变化。

import Foundation

struct RetentionResult: Sendable {
    let netGrowthRate: Double        // 净增长率（正=增长，负=流失）
    let avgDailyChange: Double
    let isChurning: Bool             // 连续多天净减少
    let churnRiskLevel: String       // "None" / "Low" / "Medium" / "High"
    let startFollowers: Int
    let endFollowers: Int
}

protocol RetentionAnalysisServiceProtocol: Sendable {
    func analyze(snapshots: [Snapshot]) async -> RetentionResult
    func churnRisk(consecutiveNegativeDays: Int) -> String
}

final class RetentionAnalysisService: RetentionAnalysisServiceProtocol {

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

    func churnRisk(consecutiveNegativeDays: Int) -> String {
        switch consecutiveNegativeDays {
        case 0..<2:  return "None"
        case 2..<5:  return "Low"
        case 5..<10: return "Medium"
        default:     return "High"
        }
    }
}
