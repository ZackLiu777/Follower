//
//  ComparisonService.swift
//  Follower
//
//  Gamma: 长期趋势对比（Premium）。对比两个时间周期的指标变化。

import Foundation

// MARK: - ComparisonResult

/// 周期对比结果：两个时间段的均值、变化量、变化方向和百分比
struct ComparisonResult: Sendable {
    let currentAvg: Double
    let previousAvg: Double
    let absoluteChange: Double
    let percentChange: Double
    let direction: ComparisonDirection
}

/// 对比方向枚举：上升 / 下降 / 持平
enum ComparisonDirection: String, Sendable {
    case up = "UP"
    case down = "DOWN"
    case flat = "FLAT"
}

// MARK: - ComparisonServiceProtocol

/// 趋势对比服务协议（Premium）：对比两个时间周期的指标变化
protocol ComparisonServiceProtocol: Sendable {
    /// 对比两个 Snapshot 集合的提取指标，返回变化量和方向
    func compare(
        currentSnapshots: [Snapshot],
        previousSnapshots: [Snapshot],
        extract: (Snapshot) -> Int
    ) async -> ComparisonResult
}

// MARK: - ComparisonService

/// 趋势对比服务实现：计算均值并判定方向（阈值 0.5%）
final class ComparisonService: ComparisonServiceProtocol {

    /// 对比两个集合的均值，返回变化量和方向
    func compare(
        currentSnapshots: [Snapshot],
        previousSnapshots: [Snapshot],
        extract: (Snapshot) -> Int
    ) async -> ComparisonResult {
        let currentAvg: Double = currentSnapshots.isEmpty
            ? 0 : Double(currentSnapshots.map(extract).reduce(0, +)) / Double(currentSnapshots.count)
        let previousAvg: Double = previousSnapshots.isEmpty
            ? 0 : Double(previousSnapshots.map(extract).reduce(0, +)) / Double(previousSnapshots.count)

        let absoluteChange = currentAvg - previousAvg
        let percentChange: Double = previousAvg > 0 ? (absoluteChange / previousAvg) * 100 : 0

        let direction: ComparisonDirection
        if abs(percentChange) < 0.5 { direction = .flat }
        else if percentChange > 0 { direction = .up }
        else { direction = .down }

        return ComparisonResult(
            currentAvg: currentAvg,
            previousAvg: previousAvg,
            absoluteChange: absoluteChange,
            percentChange: percentChange,
            direction: direction
        )
    }
}
