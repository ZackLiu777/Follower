//
//  FeatureEngine.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）特征工程。
//  纯函数：快照序列 → 特征行（4 维启用特征 + 截断目标），支持标准化/反标准化。
//  互动 3 维（like/comment/share rate）为预留位，真实 API 无日频数据源，
//  待数据源接入后扩展 featureCount。
//
//  v0.16：删除 lag_growth_7d —— 它与 momentum_7d 满足恒等式
//  lag_growth_7d ≡ 7 × momentum_7d，任何数据下严格线性相关（列秩亏），
//  使似然 Hessian 退化、牛顿步病态 → Laplace fit 在真实数据上失败返回 nil。
//  删除后特征满秩，数值稳定（见 docs/specs/prediction-bayesian-model.md 决策表）。
//

import Foundation

/// 增长观测点 — Service/VM 层从 Snapshot 映射
struct GrowthPoint: Sendable {
    let date: Date
    let followers: Int
}

/// 特征行：5 维特征 + 目标 y_{t+1} = max(0, Δfollowers)（截断处理负增长）
struct FeatureRow: Sendable {
    let features: [Double]
    let target: Int
}

/// 标准化统计量（训练数据均值/标准差）— 预测时用同一统计量反标准化
struct FeatureStats: Sendable {
    let means: [Double]
    let stds: [Double]
}

/// 特征构建与标准化（全部静态纯函数，确定性可测）
enum FeatureEngine {
    /// 启用特征维度（P1：4 维；互动 rate 3 维预留）
    static let featureCount = 4

    /// 从增长点序列构建特征行。
    /// 特征定义（t 时刻，全部只用 t 及之前数据，无未来泄露）：
    ///   0 log_followers  = log(followers_t)
    ///   1 momentum_7d    = (followers_t − followers_{t−7}) / 7
    ///   2 accel_7d       = 最近 7 点 (t−6...t) 最小二乘线性斜率
    ///   3 lag_growth_1d  = followers_t − followers_{t−1}
    /// 目标：target = max(0, followers_{t+1} − followers_t)
    /// 窗口：需要 t−7 与 t+1，点数 ≥ 9 才产出（窗口按索引对齐，非日历日）
    static func buildRows(points: [GrowthPoint]) -> [FeatureRow] {
        // 升序 + 同日期去重（取最后一次观测）
        let sorted = points.sorted { $0.date < $1.date }
        let deduped = deduplicate(sorted)
        let n = deduped.count
        guard n >= 9 else { return [] }

        let f = deduped.map { $0.followers }
        var rows: [FeatureRow] = []
        rows.reserveCapacity(n - 8)

        // t 从 7 到 n−2（target 需 t+1）
        for t in 7..<(n - 1) {
            let features: [Double] = [
                log(max(1, Double(f[t]))),
                Double(f[t] - f[t - 7]) / 7,
                leastSquaresSlope(f[(t - 6)...t].map(Double.init)),
                Double(f[t] - f[t - 1]),
            ]
            let target = max(0, f[t + 1] - f[t])
            rows.append(FeatureRow(features: features, target: target))
        }
        return rows
    }

    /// 标准化特征（逐维 (x − mean) / std；std 过小视为常数特征，保持 0）
    /// 目标不标准化 — 负二项对数链接，μ 与 y 同量纲
    static func standardize(rows: [FeatureRow]) -> ([FeatureRow], FeatureStats) {
        guard !rows.isEmpty else { return ([], FeatureStats(means: [], stds: [])) }
        let dim = rows[0].features.count
        var means = [Double](repeating: 0, count: dim)
        for row in rows {
            for d in 0..<dim { means[d] += row.features[d] }
        }
        for d in 0..<dim { means[d] /= Double(rows.count) }

        var stds = [Double](repeating: 0, count: dim)
        for row in rows {
            for d in 0..<dim {
                let diff = row.features[d] - means[d]
                stds[d] += diff * diff
            }
        }
        for d in 0..<dim {
            stds[d] = sqrt(stds[d] / Double(rows.count))
            if stds[d] < 1e-12 { stds[d] = 1 }  // 常数特征（预留位恒 0）不缩放
        }

        let scaled = rows.map { row in
            FeatureRow(
                features: zip(row.features, zip(means, stds)).map { x, ms in
                    (x - ms.0) / ms.1
                },
                target: row.target
            )
        }
        return (scaled, FeatureStats(means: means, stds: stds))
    }

    /// 用训练统计量反标准化（预测时对滚动特征使用同一统计量）
    static func unstandardized(features: [Double], stats: FeatureStats) -> [Double] {
        zip(features, zip(stats.means, stats.stds)).map { x, ms in x * ms.1 + ms.0 }
    }

    /// 用训练统计量标准化单个特征向量（滚动预测窗口用，与 standardize 同公式）
    static func standardize(features: [Double], stats: FeatureStats) -> [Double] {
        zip(features, zip(stats.means, stats.stds)).map { x, ms in (x - ms.0) / ms.1 }
    }

    // MARK: - Internal 纯函数（单元测试直接覆盖，@testable import）

    /// 同日期多条 → 保留最后一次观测（后到覆盖）
    static func deduplicate(_ points: [GrowthPoint]) -> [GrowthPoint] {
        var seen = Set<Date>()
        var out: [GrowthPoint] = []
        for p in points.reversed() where !seen.contains(p.date) {
            seen.insert(p.date)
            out.append(p)
        }
        return out.reversed()
    }

    /// 序列最小二乘线性斜率（x = 0...count−1）
    static func leastSquaresSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for (i, y) in values.enumerated() {
            let x = Double(i)
            sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x
        }
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }
}
