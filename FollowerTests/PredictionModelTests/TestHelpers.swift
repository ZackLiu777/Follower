//
//  TestHelpers.swift
//  FollowerTests
//
//  预测模型测试共享辅助：
//  1) TestRNG — SplitMix64 确定性随机数（适配 RandomNumberGenerator，
//     同 seed 两次采样序列完全相同，测试可精确复现）
//  2) makeSyntheticGrowthPoints — 用真值参数从负二项模型生成合成增长序列
//     （生成过程与 FeatureEngine 特征定义一致，用于 MAP 恢复与覆盖率测试）
//

import Foundation
@testable import Follower

/// 确定性随机数生成器（SplitMix64）— 测试专用，生产路径不引用
struct TestRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 用真值参数从负二项模型逐日生成增长序列（每日一个观测点）。
/// - Parameters:
///   - beta: 5 个回归系数（含截距，v0.16 删共线特征后 4 特征 + 截距），
///     与 NegativeBinomialGLM 参数布局一致
///   - phi: 离散参数
/// - Returns: count 个升序 GrowthPoint，日间隔 86400s
func makeSyntheticGrowthPoints(
    rng: inout TestRNG,
    count: Int,
    startFollowers: Int,
    beta: [Double],
    phi: Double
) -> [GrowthPoint] {
    precondition(beta.count == 5)
    var levels = [Double(startFollowers)]
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)

    for t in 0..<(count - 1) {
        var features = [Double](repeating: 0, count: 4)
        if t >= 7 {
            // 与 FeatureEngine.buildRows 同 4 维（v0.16：lag_growth_7d 已删）
            features = [
                log(max(1, levels[t])),
                (levels[t] - levels[t - 7]) / 7,
                slope(Array(levels[(t - 6)...t])),
                levels[t] - levels[t - 1],
            ]
        }
        let mu = exp(beta[0] + dot(beta, features))
        let y = sampleNegBinomial(mu: mu, phi: phi, using: &rng)
        levels.append(levels[t] + Double(y))
    }
    return levels.enumerated().map {
        GrowthPoint(date: startDate.addingTimeInterval(86_400 * Double($0.offset)), followers: Int($0.element))
    }
}

/// 序列最小二乘线性斜率（x = 0...count−1）— 与 FeatureEngine 内部实现同公式
func slope(_ values: [Double]) -> Double {
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

/// 点积（beta 含截距，与模型层同语义）
func dot(_ beta: [Double], _ x: [Double]) -> Double {
    var sum = beta[0]
    for k in 0..<(beta.count - 1) {
        sum += beta[k + 1] * x[k]
    }
    return sum
}
