//
//  RollingForecast.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）滚动预测：
//  从 Laplace 后验采样 θ → 逐日负二项采样 → 30 天累计增长分布 → 95% ETI。
//  每条路径用同一个 θ 滚动 30 天（θ 不确定性 + 观测噪声都涵盖）；
//  窗口保持 8 点（t−7...t），每天追加模拟值重算特征，用训练期同 stats 标准化。
//
//  v0.16：协方差 Cholesky 失败（数值非正定）→ 对角 jitter 重试兜底，
//  仍失败才返回 nil（防御性；根治在特征层删共线特征）。
//

import Foundation

/// 预测分布结果（30 天累计增长，单位：粉丝数）
struct ForecastDistribution: Sendable {
    /// 均值（样本均值）
    let mean: Double
    /// 中位数
    let median: Double
    /// 95% 等尾可信区间下界（ETI）
    let lowerBound: Double
    /// 95% 等尾可信区间上界（ETI）
    let upperBound: Double
    /// P(增长 > 0)
    let probabilityPositive: Double
    /// 原始样本（未排序，用于进一步概率查询）
    let samples: [Double]
    /// 逐日累计增长分位数（horizonDays+1 点：索引 0 = 起点 0，索引 d = 第 d 天累计）
    /// 用于区间时序图（预测段逐日带：95% 带 = Q2.5-Q97.5，80% 带 = Q10-Q90，50% 带 = Q25-Q75）
    let dailyLower: [Double]
    /// 逐日累计 10% 分位
    let dailyQ10: [Double]
    /// 逐日累计 25% 分位
    let dailyQ25: [Double]
    /// 逐日累计中位数
    let dailyMedian: [Double]
    /// 逐日累计 75% 分位
    let dailyQ75: [Double]
    /// 逐日累计 90% 分位
    let dailyQ90: [Double]
    /// 逐日累计上界分位（97.5%）
    let dailyUpper: [Double]
    /// 500 条逐日累计路径（每条 horizonDays+1 点）— 备用：详情页分布小图
    let paths: [[Double]]

    /// P(增长 > threshold)
    func probabilityAbove(_ threshold: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let count = samples.filter { $0 > threshold }.count
        return Double(count) / Double(samples.count)
    }
}

/// 滚动预测器 — 确定性输入 + 注入 RNG（测试用 seedable，生产用系统 RNG）
enum RollingForecast {
    static let horizonDays = 30
    static let sampleCount = 500
    /// 特征窗口点数（t−7...t，与 FeatureEngine 特征定义对齐）
    static let windowSize = 8

    /// 预测未来 30 天累计粉丝增长。
    /// - Parameter posterior: Laplace 后验近似
    /// - Parameter window: 最近观测点（升序，≥ windowSize 个）
    /// - Parameter stats: 训练期标准化统计量
    /// - Parameter generator: 注入的随机数生成器
    /// - Returns: 累计增长分布（样本数 < sampleCount 时可能部分失败返回 nil）
    static func forecast(
        posterior: PosteriorGaussian,
        window: [GrowthPoint],
        stats: FeatureStats,
        using generator: inout some RandomNumberGenerator
    ) -> ForecastDistribution? {
        guard window.count >= windowSize else { return nil }
        guard let cholesky = Self.choleskyWithJitter(posterior.covariance) else { return nil }
        let dim = NegativeBinomialGLM.parameterCount
        let betaCount = dim - 1  // β 含截距 5 个，logφ 1 个

        // 窗口起点：最近 8 点（t−7...t）的 followers 水平（升序）
        let base = Array(window.suffix(windowSize))
        var totals: [Double] = []
        totals.reserveCapacity(sampleCount)
        var paths: [[Double]] = []
        paths.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            // 从后验采样 θ ~ N(mean, Σ)：θ = mean + L·z，z ~ N(0, I)
            var theta = posterior.mean
            for k in 0..<dim {
                var z = 0.0
                for j in 0...k {
                    z += cholesky[k, j] * sampleNormal(using: &generator)
                }
                theta[k] += z
            }

            let beta = Array(theta[0..<betaCount])
            let phi = exp(theta[betaCount])

            // 滚动 30 天
            var levels = base.map { Double($0.followers) }
            var total = 0.0
            var path = [Double](repeating: 0, count: horizonDays + 1)  // path[0] = 起点 0
            for day in 0..<horizonDays {
                let last = levels.last!
                let f7ago = levels[levels.count - 7]  // t−7（levels 末尾 7 个之外的第 1 个）
                let past7 = Array(levels.suffix(7))   // t−6...t

                // v0.16：与 FeatureEngine.buildRows 同 4 维（lag_growth_7d 已删）
                let features: [Double] = [
                    log(max(1, last)),
                    (last - f7ago) / 7,
                    leastSquaresSlope(past7),
                    last - levels[levels.count - 2],
                ]
                let scaled = FeatureEngine.standardize(features: features, stats: stats)

                let mu = exp(dot(beta, scaled))
                let y = sampleNegBinomial(mu: mu, phi: phi, using: &generator)
                total += Double(y)
                levels.append(last + Double(y))
                path[day + 1] = total
            }
            totals.append(total)
            paths.append(path)
        }

        let sorted = totals.sorted()
        let count = sorted.count
        let mean = sorted.reduce(0, +) / Double(count)

        // 逐日分位数（每条路径单调不减 → 分位数亦单调不减）
        let days = horizonDays + 1
        var dailyLower = [Double](repeating: 0, count: days)
        var dailyQ10 = [Double](repeating: 0, count: days)
        var dailyQ25 = [Double](repeating: 0, count: days)
        var dailyMedian = [Double](repeating: 0, count: days)
        var dailyQ75 = [Double](repeating: 0, count: days)
        var dailyQ90 = [Double](repeating: 0, count: days)
        var dailyUpper = [Double](repeating: 0, count: days)
        for d in 0..<days {
            let dayValues = paths.map { $0[d] }.sorted()
            dailyLower[d] = dayValues[Self.quantileIndex(0.025, count)]
            dailyQ10[d] = dayValues[Self.quantileIndex(0.10, count)]
            dailyQ25[d] = dayValues[Self.quantileIndex(0.25, count)]
            dailyMedian[d] = dayValues[count / 2]
            dailyQ75[d] = dayValues[Self.quantileIndex(0.75, count)]
            dailyQ90[d] = dayValues[Self.quantileIndex(0.90, count)]
            dailyUpper[d] = dayValues[Self.quantileIndex(0.975, count)]
        }

        return ForecastDistribution(
            mean: mean,
            median: sorted[count / 2],
            lowerBound: sorted[max(0, Int(0.025 * Double(count)))],
            upperBound: sorted[min(count - 1, Int(0.975 * Double(count)))],
            probabilityPositive: Double(sorted.filter { $0 > 0 }.count) / Double(count),
            samples: totals,
            dailyLower: dailyLower,
            dailyQ10: dailyQ10,
            dailyQ25: dailyQ25,
            dailyMedian: dailyMedian,
            dailyQ75: dailyQ75,
            dailyQ90: dailyQ90,
            dailyUpper: dailyUpper,
            paths: paths
        )
    }

    /// 分位数索引（0...n−1 截断）— internal 供单元测试直接覆盖。
    /// NaN/Inf 防护：Int(NaN) 在 Swift 中为未定义行为（可能崩溃），返回 0。
    static func quantileIndex(_ q: Double, _ n: Int) -> Int {
        guard q.isFinite else { return 0 }
        return min(n - 1, max(0, Int(q * Double(n))))
    }

    /// 协方差 Cholesky 分解，失败时对角 jitter 重试（v0.16 数值非正定兜底）。
    /// 共线特征删除后协方差通常正定；此处防御对称化数值误差导致的分解失败。
    /// internal 供单元测试直接覆盖。
    static func choleskyWithJitter(_ covariance: Matrix) -> Matrix? {
        if let l = covariance.choleskyLower() { return l }
        var lambda = 1e-8
        for _ in 0..<8 {
            var jittered = covariance
            for k in 0..<covariance.rows {
                jittered[k, k] += lambda
            }
            if let l = jittered.choleskyLower() { return l }
            lambda *= 10
        }
        return nil
    }

    // MARK: - Internal 纯函数（单元测试直接覆盖，@testable import）

    /// 点积（β 含截距，与 NegativeBinomialGLM.dot 同语义）
    static func dot(_ beta: [Double], _ x: [Double]) -> Double {
        var sum = beta[0]
        for k in 0..<(beta.count - 1) {
            sum += beta[k + 1] * x[k]
        }
        return sum
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
