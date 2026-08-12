//
//  Distributions.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）概率分布工具：
//  对数伽马 / digamma / 正态 CDF / 负二项对数密度 / Gamma-Poisson 采样。
//  全部纯函数；采样器接受注入的 RandomNumberGenerator（生产用系统 RNG，测试注入 seedable）。
//

import Foundation

/// 对数伽马函数 logΓ(x) — 仅对正参数有意义（本项目 x 恒为正：y≥0、φ>0）
/// Darwin 的 lgamma 返回 (value, sign) 元组；对正参数 sign 恒为 1，直接取 value
func logGamma(_ x: Double) -> Double {
    let (value, _) = lgamma(x)
    return value
}

/// digamma 函数 ψ(x) — 渐近级数 + 递推下降（x ≥ 8 时收敛，精度 ~1e-8）
/// 负二项对数密度的梯度解析式需要 ψ(y+φ) 与 ψ(φ)
func digamma(_ x: Double) -> Double {
    var x = x
    var result = 0.0
    while x < 8 {
        result -= 1 / x
        x += 1
    }
    let inv = 1 / x
    let inv2 = inv * inv
    result += log(x) - 0.5 * inv
        - inv2 * (1.0 / 12 - inv2 * (1.0 / 120 - inv2 * (1.0 / 252)))
    return result
}

/// 标准正态 CDF Φ(z) — 用补余误差函数 erfc（Darwin 内置，无依赖）
func normalCDF(_ z: Double) -> Double {
    0.5 * erfc(-z / sqrt(2))
}

/// 负二项对数密度 log P(Y = y)：y ≥ 0，均值 μ，离散参数 φ（Var = μ + μ²/φ）
/// 公式（对数伽马展开，避免伽马-泊松混合的直接形式的下溢）：
/// logΓ(y+φ) − logΓ(φ) − logΓ(y+1) + φ·(logφ − log(φ+μ)) + y·(logμ − log(φ+μ))
func negBinomialLogPDF(y: Int, mu: Double, phi: Double) -> Double {
    guard y >= 0, mu > 0, phi > 0 else { return -Double.infinity }
    let yD = Double(y)
    let sum = mu + phi
    return logGamma(yD + phi) - logGamma(phi) - logGamma(yD + 1)
        + phi * (log(phi) - log(sum))
        + yD * (log(mu) - log(sum))
}

/// 标准正态采样 — Box-Muller 变换
func sampleNormal(using generator: inout some RandomNumberGenerator) -> Double {
    let u1 = Double.random(in: 0..<1, using: &generator).clampedNonZero
    let u2 = Double.random(in: 0..<1, using: &generator)
    return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
}

/// Gamma 采样（shape α > 0, scale θ）— Marsaglia & Tsang (2000) 拒绝法
/// shape < 1 时用 α+1 采样再乘 U^(1/α) 收缩
func sampleGamma(shape: Double, scale: Double, using generator: inout some RandomNumberGenerator) -> Double {
    guard shape > 0, scale > 0 else { return 0 }
    if shape < 1 {
        let u = Double.random(in: 0..<1, using: &generator).clampedNonZero
        return sampleGamma(shape: shape + 1, scale: scale, using: &generator) * pow(u, 1 / shape)
    }
    let d = shape - 1.0 / 3.0
    let c = 1.0 / sqrt(9 * d)
    while true {
        let x = sampleNormal(using: &generator)
        let v = 1 + c * x
        if v <= 0 { continue }
        let v3 = v * v * v
        let u = Double.random(in: 0..<1, using: &generator)
        if u < 1 - 0.0331 * x * x * x * x {
            return scale * d * v3
        }
        if log(u) < 0.5 * x * x + d * (1 - v3 + log(v3)) {
            return scale * d * v3
        }
    }
}

/// Poisson 采样（Knuth 法）— rate 较大时循环长；预测场景 rate 均值几十，可接受
func samplePoisson(rate: Double, using generator: inout some RandomNumberGenerator) -> Int {
    guard rate > 0 else { return 0 }
    let limit = exp(-rate)
    var count = 0
    var product = 1.0
    while true {
        product *= Double.random(in: 0..<1, using: &generator).clampedNonZero
        if product <= limit { return count }
        count += 1
    }
}

/// 负二项采样（均值 μ，离散参数 φ）— Gamma(φ, scale=μ/φ) → Poisson 复合
func sampleNegBinomial(mu: Double, phi: Double, using generator: inout some RandomNumberGenerator) -> Int {
    guard mu > 0, phi > 0 else { return 0 }
    let rate = sampleGamma(shape: phi, scale: mu / phi, using: &generator)
    return samplePoisson(rate: rate, using: &generator)
}

private extension Double {
    /// 采样辅助：避免 log(0)/除 0
    var clampedNonZero: Double {
        self == 0 ? .leastNonzeroMagnitude : self
    }
}
