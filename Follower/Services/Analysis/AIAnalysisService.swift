//
//  AIAnalysisService.swift
//  Follower
//
//  Gamma: 本地 AI 分析（Premium）。占位实现 — 规则引擎阈值判断。
//  未来替换为 CreateML / Core ML 模型推理。

import Foundation

struct AIInsight: Sendable, Codable {
    let type: InsightType
    let title: String
    let detail: String
    let severity: InsightSeverity
}

enum InsightType: String, Sendable, Codable {
    case anomaly
    case trend
    case summary
    case recommendation
}

enum InsightSeverity: String, Sendable, Codable {
    case info
    case warning
    case critical
}

protocol AIAnalysisServiceProtocol: Sendable {
    func analyze(snapshots: [Snapshot]) async -> [AIInsight]
}

final class AIAnalysisService: AIAnalysisServiceProtocol {

    /// 规则引擎：检测异常 + 生成摘要 + 建议
    func analyze(snapshots: [Snapshot]) async -> [AIInsight] {
        var insights: [AIInsight] = []
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard sorted.count >= 3 else { return insights }

        // 1. 异常检测 — 粉丝突变
        if let anomaly = detectFollowerAnomaly(sorted) {
            insights.append(anomaly)
        }

        // 2. 互动率突变检测
        if let engagementDrop = detectEngagementDrop(sorted) {
            insights.append(engagementDrop)
        }

        // 3. 摘要
        insights.append(generateSummary(sorted))

        return insights
    }

    private func detectFollowerAnomaly(_ snapshots: [Snapshot]) -> AIInsight? {
        let recent = snapshots.suffix(3)
        let earlier = snapshots.prefix(snapshots.count - 3)
        guard !earlier.isEmpty else { return nil }

        let recentAvg = Double(recent.reduce(0) { $0 + $1.followersCount }) / Double(recent.count)
        let earlierAvg = Double(earlier.reduce(0) { $0 + $1.followersCount }) / Double(earlier.count)

        let change = earlierAvg > 0 ? abs(recentAvg - earlierAvg) / earlierAvg : 0
        guard change > 0.10 else { return nil }

        let direction = recentAvg > earlierAvg ? "surge" : "drop"
        return AIInsight(
            type: .anomaly,
            title: "Follower \(direction) detected",
            detail: "Your followers \(direction == "surge" ? "surged" : "dropped") by \(String(format: "%.0f", change * 100))% in the last 3 days compared to the previous period.",
            severity: change > 0.20 ? .critical : .warning
        )
    }

    private func detectEngagementDrop(_ snapshots: [Snapshot]) -> AIInsight? {
        let recent = snapshots.suffix(3)
        let earlier = snapshots.prefix(max(snapshots.count - 3, 1))
        guard !earlier.isEmpty else { return nil }

        let recentRate = recent.map(\.engagementRate).reduce(0, +) / Double(recent.count)
        let earlierRate = earlier.map(\.engagementRate).reduce(0, +) / Double(earlier.count)

        let drop = earlierRate - recentRate
        guard drop > 0.01 else { return nil }

        return AIInsight(
            type: .anomaly,
            title: "Engagement rate declining",
            detail: "Your engagement rate dropped by \(String(format: "%.1f", drop * 100)) percentage points recently.",
            severity: drop > 0.03 ? .warning : .info
        )
    }

    private func generateSummary(_ snapshots: [Snapshot]) -> AIInsight {
        let first = snapshots.first!
        let last = snapshots.last!
        let followerChange = last.followersCount - first.followersCount
        let direction = followerChange >= 0 ? "grown" : "decreased"

        return AIInsight(
            type: .summary,
            title: "Period Summary",
            detail: "Your followers have \(direction) by \(abs(followerChange)) over \(snapshots.count) data points. Current engagement rate: \(String(format: "%.1f", last.engagementRate * 100))%.",
            severity: .info
        )
    }
}
