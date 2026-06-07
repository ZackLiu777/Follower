//
//  ScoringService.swift
//  Follower
//
//  Gamma: 互动质量评分（Premium）。0-100 分，纯确定性计算。

import Foundation

// MARK: - ScoringResult

struct ScoringResult: Sendable {
    let score: Double          // 0-100
    let likesWeight: Double
    let commentsWeight: Double
    let sharesWeight: Double
    let engagementRate: Double
    let label: String          // "优质" / "良好" / "一般" / "较低"
}

// MARK: - ScoringServiceProtocol

protocol ScoringServiceProtocol: Sendable {
    func scoreEngagement(snapshots: [Snapshot]) async -> ScoringResult
}

// MARK: - ScoringService

final class ScoringService: ScoringServiceProtocol {

    /// 互动质量评分：加权计算 (likes + comments×3 + shares×5) / views，归一化到 0-100
    func scoreEngagement(snapshots: [Snapshot]) async -> ScoringResult {
        guard !snapshots.isEmpty else {
            return ScoringResult(score: 0, likesWeight: 0, commentsWeight: 0, sharesWeight: 0, engagementRate: 0, label: "No data")
        }

        let totalLikes = Double(snapshots.reduce(0) { $0 + $1.totalLikes })
        let totalComments = Double(snapshots.reduce(0) { $0 + $1.totalComments })
        let totalShares = Double(snapshots.reduce(0) { $0 + $1.totalShares })
        let totalViews = Double(snapshots.reduce(0) { $0 + $1.totalViews })

        let commentWeight: Double = 3.0
        let shareWeight: Double = 5.0
        let likesWeight: Double = 1.0

        let rawScore: Double
        if totalViews > 0 {
            rawScore = ((totalLikes * likesWeight) + (totalComments * commentWeight) + (totalShares * shareWeight)) / totalViews * 100
        } else {
            rawScore = 0
        }

        let score = min(100, max(0, rawScore))
        let rate: Double = totalViews > 0 ? (totalLikes + totalComments + totalShares) / totalViews : 0

        let label: String
        switch score {
        case 80...100: label = "Excellent"
        case 60..<80:  label = "Great"
        case 40..<60:  label = "Good"
        case 20..<40:  label = "Fair"
        default:        label = "Low"
        }

        return ScoringResult(score: score, likesWeight: likesWeight, commentsWeight: commentWeight, sharesWeight: shareWeight, engagementRate: rate, label: label)
    }
}
