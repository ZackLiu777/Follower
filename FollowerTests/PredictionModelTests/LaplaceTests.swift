//
//  LaplaceTests.swift
//  FollowerTests
//
//  Laplace 近似测试：
//  冷启动门槛（<30 行 → nil）、合成数据 MAP 恢复真值（宽容差）、
//  协方差正定性、同数据两次拟合确定性。
//

import Testing
import Foundation
@testable import Follower

struct LaplaceTests {

    /// 真值参数：截距 log(8)，momentum 系数 0.05，其余 0；φ=10
    /// 注意：momentum/accel/lag 为原始量纲特征（≈ 日均增长 10~20），
    /// 系数必须小（0.05·14 ≈ 0.7 → μ ≈ 16）；0.5·14 = 7 → μ = 8·e⁷ 正反馈
    /// 超指数爆炸（特征数千 → Hessian ~1e9 → 数值共线 → fit nil）。
    private func makeData(count: Int, seed: UInt64) -> [GrowthPoint] {
        var rng = TestRNG(seed: seed)
        return makeSyntheticGrowthPoints(
            rng: &rng, count: count, startFollowers: 10_000,
            beta: [log(8), 0.05, 0.0, 0.0, 0.0], phi: 10
        )
    }

    /// 冷启动：rows < minRows(30) → nil；正好 30 行 → 拟合成功
    @Test
    func testColdStartThreshold() {
        // 38 点 → 30 行；37 点 → 29 行
        let rows30 = FeatureEngine.buildRows(points: makeData(count: 38, seed: 1))
        #expect(rows30.count == 30)
        #expect(LaplaceApproximation.fit(rows: rows30) != nil)

        let rows29 = FeatureEngine.buildRows(points: makeData(count: 37, seed: 2))
        #expect(rows29.count == 29)
        #expect(LaplaceApproximation.fit(rows: rows29) == nil)
    }

    /// 合成数据（160 点）MAP 恢复真值（宽容差，特征共线放宽）
    @Test
    func testMAPRecoversTrueParameters() {
        let points = makeData(count: 160, seed: 3)
        let rows = FeatureEngine.buildRows(points: points)
        guard let posterior = LaplaceApproximation.fit(rows: rows) else {
            Issue.record("fit 返回 nil")
            return
        }
        #expect(posterior.mean.count == NegativeBinomialGLM.parameterCount)
        #expect(posterior.iterations <= 100)

        // β0 截距 ≈ log(8) = 2.079（容差放宽）
        #expect(abs(posterior.mean[0] - log(8)) < 1.0)
        // β1 (momentum) ≈ 0.05
        #expect(abs(posterior.mean[1] - 0.05) < 0.3)
        // 零系数特征被正则先验拉向 0
        for k in 2..<5 {
            #expect(abs(posterior.mean[k]) < 0.5)
        }
        // φ ≈ 10（logφ ≈ 2.303，容差放宽）
        #expect(abs(exp(posterior.mean[5]) - 10) < 8)
    }

    /// 协方差必须正定（Cholesky 可分解，否则无法采样）
    @Test
    func testCovariancePositiveDefinite() {
        let rows = FeatureEngine.buildRows(points: makeData(count: 120, seed: 4))
        guard let posterior = LaplaceApproximation.fit(rows: rows) else {
            Issue.record("fit 返回 nil")
            return
        }
        #expect(posterior.covariance.rows == NegativeBinomialGLM.parameterCount)
        #expect(posterior.covariance.choleskyLower() != nil)
        // 对角元（方差）应为正
        for k in 0..<posterior.covariance.rows {
            #expect(posterior.covariance[k, k] > 0)
        }
    }

    /// 确定性：同数据两次拟合 → 相同 mean 与协方差
    @Test
    func testFitDeterministic() {
        let rows = FeatureEngine.buildRows(points: makeData(count: 100, seed: 5))
        let a = LaplaceApproximation.fit(rows: rows)!
        let b = LaplaceApproximation.fit(rows: rows)!
        for k in 0..<a.mean.count {
            #expect(a.mean[k] == b.mean[k])
        }
        for r in 0..<a.covariance.rows {
            for c in 0..<a.covariance.cols {
                #expect(a.covariance[r, c] == b.covariance[r, c])
            }
        }
    }
}
