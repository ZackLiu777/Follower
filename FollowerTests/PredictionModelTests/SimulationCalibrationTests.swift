//
//  SimulationCalibrationTests.swift
//  FollowerTests
//
//  预测校准测试（覆盖率的经验验证）：
//  20 组参数各异的合成数据，训练 200 点 + 真实未来 30 天累计，
//  检查 95% 可信区间覆盖率。模型与生成过程同构 → 理论覆盖率 ~0.95，
//  允许 Laplace 近似 + 采样噪声，断言下限 0.70（14/20）。
//

import Testing
import Foundation
@testable import Follower

struct SimulationCalibrationTests {

    /// 20 组参数组合：φ ∈ {5, 10, 20}，起步粉丝数 ∈ {5k, 10k, 20k}
    private static let trials: [(phi: Double, start: Int)] = [
        (5, 5_000), (10, 5_000), (20, 5_000),
        (5, 10_000), (10, 10_000), (20, 10_000),
        (5, 20_000), (10, 20_000), (20, 20_000),
        (8, 7_000), (8, 14_000), (8, 28_000),
        (12, 6_000), (12, 12_000), (12, 24_000),
        (6, 9_000), (6, 18_000), (6, 30_000),
        (15, 8_000), (15, 16_000),
    ]

    @Test
    func testCoverageRate() {
        var covered = 0
        var details: [String] = []

        for (index, trial) in Self.trials.enumerated() {
            // 每组固定派生 seed → 完全确定性
            // 系数取小值（momentum/accel 为原始量纲特征 ≈ 日均增长 10~30）：
            // 0.05·20 ≈ 1 → μ ≈ 27；系数过大（0.35·20 = 7）→ 正反馈超指数爆炸
            // （特征数千 → Hessian ~1e9 → 数值共线 → fit nil）
            var rng = TestRNG(seed: UInt64(1_000 + index * 37))
            let points = makeSyntheticGrowthPoints(
                rng: &rng, count: 230, startFollowers: trial.start,
                beta: [log(10), 0.05, 0.005, 0.0, 0.0], phi: trial.phi
            )

            // 训练：前 200 点；真实未来：后 30 点的累计增长（生成过程 y ≥ 0）
            let train = Array(points.prefix(200))
            let rows = FeatureEngine.buildRows(points: train)
            guard let posterior = LaplaceApproximation.fit(rows: rows) else {
                details.append("trial \(index): fit nil")
                continue
            }
            let (_, stats) = FeatureEngine.standardize(rows: rows)
            let window = Array(train.suffix(RollingForecast.windowSize))

            var fRNG = TestRNG(seed: UInt64(5_000 + index * 53))
            guard let forecast = RollingForecast.forecast(
                posterior: posterior, window: window, stats: stats, using: &fRNG
            ) else {
                details.append("trial \(index): forecast nil")
                continue
            }

            // 真实 30 天累计增长 = 最后一个点 − 训练期末
            let actual = Double(points.last!.followers - train.last!.followers)
            let hit = actual >= forecast.lowerBound && actual <= forecast.upperBound
            if hit { covered += 1 }
            details.append("trial \(index): actual=\(actual) CI=[\(forecast.lowerBound), \(forecast.upperBound)] \(hit ? "✓" : "✗")")
        }

        // 理论覆盖率 ~0.95；20 组采样噪声下下限取 0.70（flaky 防护）
        let rate = Double(covered) / Double(Self.trials.count)
        #expect(rate >= 0.70, "覆盖率 \(rate) 过低（\(covered)/\(Self.trials.count) 组）")
        #expect(rate <= 1.0)
    }
}
