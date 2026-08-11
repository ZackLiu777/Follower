//
//  DistributionTests.swift
//  FollowerTests
//
//  概率分布工具测试：
//  对数伽马 / digamma / 正态 CDF 已知值精确断言；
//  采样器用固定 seed 检查均值/方差统计量（确定性结果，容差宽裕）。
//

import Testing
import Foundation
@testable import Follower

struct DistributionTests {

    // MARK: - logGamma 已知值

    @Test
    func testLogGammaKnownValues() {
        #expect(abs(logGamma(1) - 0) < 1e-10)
        #expect(abs(logGamma(2) - 0) < 1e-10)
        #expect(abs(logGamma(3) - log(2)) < 1e-10)
        // logΓ(0.5) = log(√π)
        #expect(abs(logGamma(0.5) - 0.5 * log(.pi)) < 1e-10)
    }

    /// 递推恒等式：logΓ(x+1) = logΓ(x) + log(x)（多个 x 值）
    @Test
    func testLogGammaRecurrence() {
        let xs: [Double] = [0.5, 1.0, 3.7, 9.25, 42.0]
        for x in xs {
            let lhs = logGamma(x + 1)
            let rhs = logGamma(x) + log(x)
            #expect(abs(lhs - rhs) < 1e-9, "x=\(x): \(lhs) vs \(rhs)")
        }
    }

    /// 极小正参数：logΓ(x) ≈ −log(x) − γ（γ 为欧拉常数；x → 0+ 首阶展开）
    @Test
    func testLogGammaTinyPositive() {
        let eulerGamma = 0.5772156649015329
        let x = 1e-6
        let approx = -log(x) - eulerGamma
        #expect(abs(logGamma(x) - approx) < 1e-3)
        #expect(logGamma(x).isFinite)
    }

    // MARK: - digamma 已知值

    @Test
    func testDigammaKnownValues() {
        let eulerGamma = 0.5772156649015329
        #expect(abs(digamma(1) + eulerGamma) < 1e-6)   // ψ(1) = −γ
        #expect(abs(digamma(2) - (1 - eulerGamma)) < 1e-6)  // ψ(2) = 1 − γ
        // ψ(0.5) = −γ − 2·ln2
        #expect(abs(digamma(0.5) + (eulerGamma + 2 * log(2))) < 1e-5)
    }

    /// 递推恒等式：ψ(x+1) = ψ(x) + 1/x（覆盖 <8 递推路径与渐近路径）
    @Test
    func testDigammaRecurrence() {
        let xs: [Double] = [0.5, 1.0, 2.0, 3.7, 7.1]
        for x in xs {
            let lhs = digamma(x + 1)
            let rhs = digamma(x) + 1 / x
            #expect(abs(lhs - rhs) < 1e-7, "x=\(x): \(lhs) vs \(rhs)")
        }
    }

    /// 大参数渐近：ψ(x) ≈ log(x) − 1/(2x)（x = 100、1000）
    @Test
    func testDigammaLargeArgument() {
        for x in [100.0, 1000.0] {
            let approx = log(x) - 0.5 / x
            #expect(abs(digamma(x) - approx) < 1e-8 * log(x), "x=\(x)")
        }
    }

    // MARK: - normalCDF 已知值

    @Test
    func testNormalCDFKnownValues() {
        #expect(abs(normalCDF(0) - 0.5) < 1e-12)
        #expect(abs(normalCDF(1.96) - 0.975) < 1e-3)
        #expect(abs(normalCDF(-1.96) - 0.025) < 1e-3)
        #expect(abs(normalCDF(2.326) - 0.99) < 1e-3)
    }

    /// 对称性：Φ(−z) = 1 − Φ(z)（多个 z）
    @Test
    func testNormalCDFSymmetry() {
        for z in [0.1, 1.0, 2.5, 4.0] {
            let phiZ = normalCDF(z)
            let phiNeg = normalCDF(-z)
            #expect(abs(phiZ + phiNeg - 1) < 1e-10, "z=\(z)")
        }
    }

    /// 单调性与尾部极限：Φ 严格递增，尾部趋近 0/1
    @Test
    func testNormalCDFMonotonicAndTails() {
        let zs = stride(from: -4.0, through: 4.0, by: 0.5).map { $0 }
        for i in 1..<zs.count {
            #expect(normalCDF(zs[i - 1]) < normalCDF(zs[i]))
        }
        #expect(abs(normalCDF(-6) - 0) < 1e-8)
        #expect(abs(normalCDF(6) - 1) < 1e-8)
        // 中段近似线性（0 附近斜率为 1/√(2π)）
        let slope = (normalCDF(0.5) - normalCDF(-0.5)) / 1.0
        #expect(abs(slope - 1 / sqrt(2 * .pi)) < 1e-3)
    }

    // MARK: - negBinomialLogPDF 手算

    /// y=0, μ=10, φ=5：logΓ(5)−logΓ(5)−logΓ(1)+5·log(5/15) = 5·log(1/3)
    @Test
    func testNegBinomialLogPDFHandComputed() {
        let logP = negBinomialLogPDF(y: 0, mu: 10, phi: 5)
        #expect(abs(logP - 5 * log(1.0 / 3.0)) < 1e-9)
    }

    /// 非法参数（负 y、非正 μ/φ）→ −∞
    @Test
    func testNegBinomialLogPDFInvalidInputs() {
        #expect(negBinomialLogPDF(y: -1, mu: 10, phi: 5) == -.infinity)
        #expect(negBinomialLogPDF(y: 0, mu: 0, phi: 5) == -.infinity)
        #expect(negBinomialLogPDF(y: 0, mu: 10, phi: 0) == -.infinity)
    }

    /// y=1, μ=10, φ=5：logΓ(6)−logΓ(5)−logΓ(2) + 5·log(5/15) + 1·(log10−log15)
    /// = log(5) − 0 + 5·log(1/3) + log(2/3)
    @Test
    func testNegBinomialLogPDFY1HandComputed() {
        let logP = negBinomialLogPDF(y: 1, mu: 10, phi: 5)
        let expected = log(5) - logGamma(2) + 5 * log(5.0 / 15.0) + log(10.0 / 15.0)
        #expect(abs(logP - expected) < 1e-9)
    }

    /// 概率质量归一化：Σ_y exp(logPDF(y)) ≈ 1（y 取 0...200 覆盖 8σ 尾部）
    @Test
    func testNegBinomialLogPDFNormalizes() {
        for (mu, phi) in [(1.0, 5.0), (10.0, 5.0), (25.0, 40.0)] {
            var sum = 0.0
            for y in 0...200 {
                sum += exp(negBinomialLogPDF(y: y, mu: mu, phi: phi))
            }
            #expect(abs(sum - 1) < 1e-8, "μ=\(mu) φ=\(phi): Σ=\(sum)")
        }
    }

    /// 模式位置：负二项 logPDF 峰值随 μ 增大右移（y* ≈ μ 附近）
    @Test
    func testNegBinomialLogPDFModeTracksMean() {
        let phi = 10.0
        for mu in [2.0, 8.0, 20.0] {
            var best = Double.leastNormalMagnitude
            var bestY = -1
            for y in 0...60 {
                let p = exp(negBinomialLogPDF(y: y, mu: mu, phi: phi))
                if p > best { best = p; bestY = y }
            }
            #expect(Double(bestY) < mu + 4 && Double(bestY) > mu - 6, "μ=\(mu) 模式 y*=\(bestY)")
        }
    }

    // MARK: - 采样统计量（固定 seed，确定性）

    @Test
    func testSampleNormalStatistics() {
        var rng = TestRNG(seed: 42)
        var sum = 0.0, sumSq = 0.0
        let n = 20_000
        for _ in 0..<n {
            let z = sampleNormal(using: &rng)
            sum += z
            sumSq += z * z
        }
        let mean = sum / Double(n)
        let variance = sumSq / Double(n) - mean * mean
        #expect(abs(mean) < 0.05)
        #expect(abs(variance - 1) < 0.05)
    }

    @Test
    func testSamplePoissonStatistics() {
        var rng = TestRNG(seed: 7)
        var sum = 0.0
        let n = 20_000
        for _ in 0..<n {
            sum += Double(samplePoisson(rate: 12, using: &rng))
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 12) < 0.3)
    }

    /// rate ≤ 0 → 恒返回 0（防护分支）
    @Test
    func testSamplePoissonZeroRate() {
        var rng = TestRNG(seed: 3)
        for _ in 0..<1000 {
            #expect(samplePoisson(rate: 0, using: &rng) == 0)
            #expect(samplePoisson(rate: -5, using: &rng) == 0)
        }
    }

    /// 小 rate：均值 ≈ rate（Knuth 法小值路径）
    @Test
    func testSamplePoissonSmallRate() {
        var rng = TestRNG(seed: 21)
        var sum = 0.0
        let n = 20_000
        for _ in 0..<n {
            sum += Double(samplePoisson(rate: 0.5, using: &rng))
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 0.5) < 0.05)
    }

    @Test
    func testSampleGammaStatistics() {
        var rng = TestRNG(seed: 99)
        var sum = 0.0
        let n = 20_000
        for _ in 0..<n {
            sum += sampleGamma(shape: 2, scale: 3, using: &rng)
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 6) < 0.3)  // E = shape·scale = 6
    }

    /// shape < 1 收缩分支：E[Gamma(0.5, 2)] = 1
    @Test
    func testSampleGammaSmallShape() {
        var rng = TestRNG(seed: 13)
        var sum = 0.0
        let n = 20_000
        for _ in 0..<n {
            sum += sampleGamma(shape: 0.5, scale: 2, using: &rng)
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 1.0) < 0.05)
    }

    /// scale 线性缩放：Gamma(α, 2s) 均值 = 2 × Gamma(α, s) 均值
    @Test
    func testSampleGammaScaleLinear() {
        var rngA = TestRNG(seed: 55)
        var rngB = TestRNG(seed: 55)
        var sumA = 0.0, sumB = 0.0
        let n = 10_000
        for _ in 0..<n {
            sumA += sampleGamma(shape: 4, scale: 1, using: &rngA)
            sumB += sampleGamma(shape: 4, scale: 2, using: &rngB)
        }
        let meanA = sumA / Double(n)
        let meanB = sumB / Double(n)
        #expect(abs(meanB - 2 * meanA) < 0.1)
    }

    /// 非法参数（shape/scale ≤ 0）→ 0（防护分支）
    @Test
    func testSampleGammaInvalidParams() {
        var rng = TestRNG(seed: 8)
        for _ in 0..<1000 {
            #expect(sampleGamma(shape: 0, scale: 3, using: &rng) == 0)
            #expect(sampleGamma(shape: 2, scale: -1, using: &rng) == 0)
        }
    }

    @Test
    func testSampleNegBinomialStatistics() {
        var rng = TestRNG(seed: 123)
        var sum = 0.0, sumSq = 0.0
        let n = 20_000
        for _ in 0..<n {
            let y = Double(sampleNegBinomial(mu: 10, phi: 5, using: &rng))
            sum += y
            sumSq += y * y
        }
        let mean = sum / Double(n)
        let variance = sumSq / Double(n) - mean * mean
        #expect(abs(mean - 10) < 0.4)
        // Var = μ + μ²/φ = 30
        #expect(abs(variance - 30) < 3)
    }

    /// 小均值：E ≈ μ，且 y ≥ 0（y 值域保证）
    @Test
    func testSampleNegBinomialSmallMu() {
        var rng = TestRNG(seed: 31)
        var sum = 0.0
        let n = 20_000
        for _ in 0..<n {
            let y = sampleNegBinomial(mu: 0.4, phi: 3, using: &rng)
            #expect(y >= 0)
            sum += Double(y)
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 0.4) < 0.05)
    }

    /// 大 φ（→ 泊松极限）：方差 → μ（Var = μ + μ²/φ → μ）
    @Test
    func testSampleNegBinomialHighPhiApproachesPoisson() {
        var rng = TestRNG(seed: 77)
        var sum = 0.0, sumSq = 0.0
        let n = 20_000
        for _ in 0..<n {
            let y = Double(sampleNegBinomial(mu: 10, phi: 500, using: &rng))
            sum += y
            sumSq += y * y
        }
        let mean = sum / Double(n)
        let variance = sumSq / Double(n) - mean * mean
        #expect(abs(mean - 10) < 0.4)
        // 泊松极限 Var = 10；φ=500 时理论 Var = 10.2
        #expect(abs(variance - 10) < 1.2)
    }

    /// 非法参数（μ/φ ≤ 0）→ 0（防护分支）
    @Test
    func testSampleNegBinomialInvalidParams() {
        var rng = TestRNG(seed: 9)
        for _ in 0..<1000 {
            #expect(sampleNegBinomial(mu: 0, phi: 5, using: &rng) == 0)
            #expect(sampleNegBinomial(mu: 10, phi: -2, using: &rng) == 0)
        }
    }

    /// 同 seed 两次采样序列一致（确定性）
    @Test
    func testSamplingDeterminism() {
        var rngA = TestRNG(seed: 5)
        var rngB = TestRNG(seed: 5)
        for _ in 0..<100 {
            #expect(sampleNormal(using: &rngA) == sampleNormal(using: &rngB))
        }
        // Gamma / Poisson / NegBinomial 同样确定性
        var gA = TestRNG(seed: 6), gB = TestRNG(seed: 6)
        var pA = TestRNG(seed: 7), pB = TestRNG(seed: 7)
        var nA = TestRNG(seed: 8), nB = TestRNG(seed: 8)
        for _ in 0..<100 {
            #expect(sampleGamma(shape: 2, scale: 3, using: &gA) == sampleGamma(shape: 2, scale: 3, using: &gB))
            #expect(samplePoisson(rate: 12, using: &pA) == samplePoisson(rate: 12, using: &pB))
            #expect(sampleNegBinomial(mu: 10, phi: 5, using: &nA) == sampleNegBinomial(mu: 10, phi: 5, using: &nB))
        }
    }

    /// 标准正态分位数经验验证：P(|z| < 1.96) ≈ 0.95（固定 seed，容差 1%）
    @Test
    func testSampleNormalQuantiles() {
        var rng = TestRNG(seed: 42)
        let n = 20_000
        var within = 0
        for _ in 0..<n {
            let z = sampleNormal(using: &rng)
            if abs(z) < 1.96 { within += 1 }
        }
        let rate = Double(within) / Double(n)
        #expect(abs(rate - 0.95) < 0.01)
    }
}
