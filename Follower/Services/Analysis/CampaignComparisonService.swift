//
//  CampaignComparisonService.swift
//  Follower
//
//  Phi: 投放效果跟踪服务（Premium）。
//  对比两个时间段的关键指标变化：粉丝、互动率、覆盖率。
//

import Foundation

// MARK: - CampaignResult

/// 投放效果对比结果
struct CampaignResult: Sendable {
    /// 前期粉丝数（起始）
    let preFollowers: Int
    /// 后期粉丝数（结束）
    let postFollowers: Int
    /// 粉丝变化
    let followerDelta: Int
    /// 前期互动率
    let preEngagement: Double
    /// 后期互动率
    let postEngagement: Double
    /// 互动率变化
    let engagementDelta: Double
    /// 前期覆盖人数
    let preViews: Int
    /// 后期覆盖人数
    let postViews: Int
    /// 覆盖变化
    let viewsDelta: Int
    /// 粉丝增长率（百分比）
    var followerGrowthRate: Double {
        guard preFollowers > 0 else { return 0 }
        return Double(followerDelta) / Double(preFollowers) * 100
    }
}

// MARK: - CampaignComparisonServiceProtocol

protocol CampaignComparisonServiceProtocol: Sendable {
    /// 对比两个时间段的指标变化
    func compare(
        preSnapshots: [Snapshot],
        postSnapshots: [Snapshot]
    ) async -> CampaignResult
}

// MARK: - CampaignComparisonService

/// 投放效果对比服务：pre vs post 两个时间段的聚合指标对比
final class CampaignComparisonService: CampaignComparisonServiceProtocol {

    func compare(
        preSnapshots: [Snapshot],
        postSnapshots: [Snapshot]
    ) async -> CampaignResult {
        let preFollowers = averageInt(preSnapshots, \.followersCount)
        let postFollowers = averageInt(postSnapshots, \.followersCount)
        let preEngagement = averageDouble(preSnapshots, \.engagementRate)
        let postEngagement = averageDouble(postSnapshots, \.engagementRate)
        let preViews = averageInt(preSnapshots, \.totalViews)
        let postViews = averageInt(postSnapshots, \.totalViews)

        return CampaignResult(
            preFollowers: preFollowers,
            postFollowers: postFollowers,
            followerDelta: postFollowers - preFollowers,
            preEngagement: preEngagement,
            postEngagement: postEngagement,
            engagementDelta: postEngagement - preEngagement,
            preViews: preViews,
            postViews: postViews,
            viewsDelta: postViews - preViews
        )
    }

    // MARK: - Helpers

    private func averageInt(_ snapshots: [Snapshot], _ keyPath: KeyPath<Snapshot, Int>) -> Int {
        guard !snapshots.isEmpty else { return 0 }
        let sum = snapshots.reduce(0) { $0 + $1[keyPath: keyPath] }
        return sum / snapshots.count
    }

    private func averageDouble(_ snapshots: [Snapshot], _ keyPath: KeyPath<Snapshot, Double>) -> Double {
        guard !snapshots.isEmpty else { return 0 }
        return snapshots.reduce(0) { $0 + $1[keyPath: keyPath] } / Double(snapshots.count)
    }
}
