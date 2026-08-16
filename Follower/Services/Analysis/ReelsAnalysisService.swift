//
//  ReelsAnalysisService.swift
//  Follower
//
//  Premium: Reels 深度分析（Phi+）— 完播率 / Saves / Shares 权重分析。
//  - 单帖深度指标：plays / reach / saved / shares / avg_watch_time（per-media insights）
//  - 完播率 = 平均观看时长 ÷ 视频时长
//  - 权重分析：Saves 率（saved/plays）、Shares 率（shares/plays）
//    —— 推荐算法中时长与转发分享是推入 Explore 的核心驱动
//  - 确定性纯计算（指标来自 API 层；聚合逻辑可测）
//

import Foundation

// MARK: - 结果模型

/// 单条 Reel 深度表现
struct ReelPerformance: Sendable {
    let mediaID: String
    let caption: String
    /// 视频时长（秒）
    let duration: Int
    /// 播放量
    let plays: Double
    /// 完播率（0-1，avg_watch_time/duration）
    let completionRate: Double
    /// Saves
    let saves: Double
    /// Shares
    let shares: Double
    /// Saves 率（saved/plays）
    let saveRate: Double
    /// Shares 率（shares/plays）
    let shareRate: Double
}

/// Reels 分析结果
struct ReelsAnalysisResult: Sendable {
    /// 参与分析的 Reel 数
    let reelCount: Int
    /// 平均完播率（0-1）
    let avgCompletionRate: Double
    /// 平均 Saves 率
    let avgSaveRate: Double
    /// 平均 Shares 率
    let avgShareRate: Double
    /// 完播率最高的 Reel
    let bestReel: ReelPerformance?
    /// 所有 Reel 表现（按完播率降序）
    let reels: [ReelPerformance]
}

// MARK: - Service

/// Reels 深度分析服务 — 拉取 per-media insights 并聚合（确定性聚合逻辑）
struct ReelsAnalysisService: Sendable {

    /// 分析的 Reel 上限（per-media insights 逐帖调用，控制 API 频率）
    static let maxReels = 5

    /// 从 API 原始指标映射单帖表现；指标缺失 → nil（开发模式 insights 空数组）
    static func mapReel(
        media: IGMedia,
        insights: [IGInsightValue]
    ) -> ReelPerformance? {
        guard media.mediaType == "VIDEO", let duration = media.mediaDuration, duration > 0 else { return nil }

        func value(_ name: String) -> Double? {
            insights.first { $0.name == name }?
                .totalValue?.breakdowns?.first?.value
        }
        guard let plays = value("plays"), plays > 0 else { return nil }
        let saved = value("saved") ?? 0
        let shares = value("shares") ?? 0
        let avgWatch = value("avg_watch_time") ?? 0

        let completion = min(1.0, max(0.0, avgWatch / Double(duration)))
        return ReelPerformance(
            mediaID: media.id,
            caption: media.caption ?? "",
            duration: duration,
            plays: plays,
            completionRate: completion,
            saves: saved,
            shares: shares,
            saveRate: plays > 0 ? saved / plays : 0,
            shareRate: plays > 0 ? shares / plays : 0
        )
    }

    /// 聚合多条 Reel 表现（确定性）
    static func aggregate(_ performances: [ReelPerformance]) -> ReelsAnalysisResult? {
        guard !performances.isEmpty else { return nil }
        let sorted = performances.sorted { $0.completionRate > $1.completionRate }
        let n = Double(performances.count)
        return ReelsAnalysisResult(
            reelCount: performances.count,
            avgCompletionRate: performances.map(\.completionRate).reduce(0, +) / n,
            avgSaveRate: performances.map(\.saveRate).reduce(0, +) / n,
            avgShareRate: performances.map(\.shareRate).reduce(0, +) / n,
            bestReel: sorted.first,
            reels: sorted
        )
    }

    /// 完播率百分比格式化辅助（0.42 → "42%"）
    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
