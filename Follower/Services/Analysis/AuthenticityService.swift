//
//  AuthenticityService.swift
//  Follower
//
//  Phi: 账号真实性评估服务（Premium）。
//  综合 Engagement Quality、粉丝增长曲线、异常检测，输出 0-100 分。
//

import Foundation

// MARK: - AuthenticityResult

/// 真实性评估结果
struct AuthenticityResult: Sendable {
    /// 综合真实性评分 0-100
    let score: Double
    /// 互动质量子分 0-100
    let engagementQuality: Double
    /// 增长模式评估（正常/可疑）
    let growthPattern: String
    /// 粉丝真实性子分 0-100
    let followerAuthenticity: Double
    /// 是否检测到异常
    let hasAnomalies: Bool
    /// 异常描述（无异常时为 nil）
    let anomalyDescription: String?
}

// MARK: - AuthenticityServiceProtocol

protocol AuthenticityServiceProtocol: Sendable {
    /// 评估账号真实性 — 综合互动质量、增长曲线、异常检测
    func assess(snapshots: [Snapshot]) async -> AuthenticityResult
}

// MARK: - AuthenticityService

/// 真实性评估服务：三维度加权评分
///   - 互动质量 (40%): 复用 ScoringService 的计算逻辑
///   - 增长模式 (30%): 分析粉丝增长曲线的平滑度
///   - 粉丝真实性 (30%): 检测 follower/engagement 比例是否合理
final class AuthenticityService: AuthenticityServiceProtocol {

    func assess(snapshots: [Snapshot]) async -> AuthenticityResult {
        guard snapshots.count >= 3 else {
            return AuthenticityResult(
                score: 0, engagementQuality: 0,
                growthPattern: "Insufficient data",
                followerAuthenticity: 0,
                hasAnomalies: false, anomalyDescription: nil
            )
        }

        // 1. 互动质量 (40%) — 基于加权互动率
        let eqScore = computeEngagementQuality(snapshots: snapshots)

        // 2. 增长模式 (30%) — 检测粉丝增长是否自然
        let (gpScore, gpLabel) = computeGrowthPattern(snapshots: snapshots)

        // 3. 粉丝真实性 (30%) — followers / engagement 比是否合理
        let faScore = computeFollowerAuthenticity(snapshots: snapshots)

        // 4. 异常检测
        let (hasAnomalies, anomalyDesc) = detectAnomalies(snapshots: snapshots)

        // 加权综合
        let total = eqScore * 0.4 + gpScore * 0.3 + faScore * 0.3
        let score = min(100, max(0, total))

        return AuthenticityResult(
            score: score,
            engagementQuality: eqScore,
            growthPattern: gpLabel,
            followerAuthenticity: faScore,
            hasAnomalies: hasAnomalies,
            anomalyDescription: anomalyDesc
        )
    }

    // MARK: - Private

    /// 互动质量评分：加权 (likes + comments×3 + shares×5) / views → 0-100
    private func computeEngagementQuality(snapshots: [Snapshot]) -> Double {
        let totalLikes = Double(snapshots.reduce(0) { $0 + $1.totalLikes })
        let totalComments = Double(snapshots.reduce(0) { $0 + $1.totalComments })
        let totalShares = Double(snapshots.reduce(0) { $0 + $1.totalShares })
        let totalViews = Double(snapshots.reduce(0) { $0 + $1.totalViews })

        guard totalViews > 0 else { return 0 }
        let raw = (totalLikes * 1.0 + totalComments * 3.0 + totalShares * 5.0) / totalViews * 100
        return min(100, max(0, raw))
    }

    /// 增长模式评估：检测粉丝增长曲线是否自然（无剧烈跳跃）
    private func computeGrowthPattern(snapshots: [Snapshot]) -> (score: Double, label: String) {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        let followers = sorted.map { Double($0.followersCount) }

        guard followers.count >= 3, let first = followers.first, let last = followers.last, first > 0 else {
            return (0, "Insufficient data")
        }

        // 计算逐日变化率的标准差 — 标准差越小越自然
        var deltas: [Double] = []
        for i in 1..<followers.count {
            let prev = followers[i - 1]
            guard prev > 0 else { continue }
            deltas.append((followers[i] - prev) / prev)
        }

        guard !deltas.isEmpty else { return (50, "Stable") }

        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0) { $0 + pow($1 - mean, 2) } / Double(deltas.count)
        let stdDev = sqrt(variance)

        // 标准差 < 1% → 自然增长（高分）
        // 标准差 1-3% → 正常
        // 标准差 > 5% → 可疑
        let score: Double
        let label: String
        if stdDev < 0.01 {
            score = 90
            label = "Natural"
        } else if stdDev < 0.03 {
            score = 70
            label = "Normal"
        } else if stdDev < 0.05 {
            score = 50
            label = "Irregular"
        } else {
            score = 25
            label = "Suspicious"
        }

        return (score, label)
    }

    /// 粉丝真实性：follower 数与 engagement 的比值是否合理
    private func computeFollowerAuthenticity(snapshots: [Snapshot]) -> Double {
        guard let latest = snapshots.max(by: { $0.observedAt < $1.observedAt }),
              latest.followersCount > 0 else { return 0 }

        let followers = Double(latest.followersCount)
        let engagement = latest.engagementRate

        // 正常账号互动率在 1-10% 之间
        // 互动率过低 (< 0.5%) → 可能是假粉
        // 互动率过高 (> 15%) → 可能是互刷
        let score: Double
        if engagement < 0.005 {
            score = max(20, engagement / 0.005 * 80)  // 0-80, scaled
        } else if engagement > 0.15 {
            score = max(30, (0.3 - engagement) / 0.15 * 70)
        } else {
            // 1-10% → healthy range
            let normalized = (engagement - 0.005) / 0.095  // 0.5% → 0, 10% → 1
            score = 60 + normalized * 40  // 60-100
        }

        return min(100, max(0, score))
    }

    /// 异常检测：查找单日粉丝变化超过 3σ 的异常点
    private func detectAnomalies(snapshots: [Snapshot]) -> (hasAnomalies: Bool, description: String?) {
        let sorted = snapshots.sorted { $0.observedAt < $1.observedAt }
        guard sorted.count >= 4 else { return (false, nil) }

        var deltas: [Double] = []
        for i in 1..<sorted.count {
            deltas.append(Double(sorted[i].followersCount - sorted[i - 1].followersCount))
        }

        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0) { $0 + pow($1 - mean, 2) } / Double(deltas.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return (false, nil) }

        var anomalyCount = 0
        for (i, delta) in deltas.enumerated() where abs(delta - mean) > 3 * stdDev {
            anomalyCount += 1
        }

        if anomalyCount > 0 {
            return (true, "\(anomalyCount) unusual spike(s) detected")
        }
        return (false, nil)
    }
}
