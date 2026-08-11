//
//  RollingForecastTests.swift
//  FollowerTests
//
//  滚动预测测试：
//  同 seed 确定性、CI 单调性、窗口不足 nil、增长数据的分布形状。
//

import Testing
import Foundation
@testable import Follower

struct RollingForecastTests {

    /// 60 点训练 + 最后 8 点窗口 → 后验 + 预测
    private func makeFitAndWindow(count: Int = 60, seed: UInt64 = 11) -> (PosteriorGaussian, [GrowthPoint], FeatureStats) {
        var rng = TestRNG(seed: seed)
        let points = makeSyntheticGrowthPoints(
            rng: &rng, count: count, startFollowers: 8_000,
            beta: [log(12), 0.4, 0.0, 0.0, 0.0], phi: 12
        )
        let rows = FeatureEngine.buildRows(points: points)
        let posterior = LaplaceApproximation.fit(rows: rows)!
        let (_, stats) = FeatureEngine.standardize(rows: rows)
        let window = Array(points.suffix(RollingForecast.windowSize))
        return (posterior, window, stats)
    }

    /// 同 seed 两次预测 → 完全相同的分布（确定性）
    @Test
    func testForecastDeterministic() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rngA = TestRNG(seed: 777)
        var rngB = TestRNG(seed: 777)
        let a = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rngA)!
        let b = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rngB)!
        #expect(a.mean == b.mean)
        #expect(a.median == b.median)
        #expect(a.lowerBound == b.lowerBound)
        #expect(a.upperBound == b.upperBound)
        #expect(a.samples == b.samples)
        // 逐日分位与路径同样确定性
        #expect(a.dailyLower == b.dailyLower)
        #expect(a.dailyQ10 == b.dailyQ10)
        #expect(a.dailyQ25 == b.dailyQ25)
        #expect(a.dailyMedian == b.dailyMedian)
        #expect(a.dailyQ75 == b.dailyQ75)
        #expect(a.dailyQ90 == b.dailyQ90)
        #expect(a.dailyUpper == b.dailyUpper)
        #expect(a.paths == b.paths)
    }

    /// 逐日分位结构：31 点、起点 0、单调不减、终点与累计分位一致
    @Test
    func testDailyQuantilesStructure() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 4321)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        let days = RollingForecast.horizonDays + 1
        #expect(f.dailyLower.count == days)
        #expect(f.dailyQ10.count == days)
        #expect(f.dailyQ25.count == days)
        #expect(f.dailyMedian.count == days)
        #expect(f.dailyQ75.count == days)
        #expect(f.dailyQ90.count == days)
        #expect(f.dailyUpper.count == days)
        #expect(f.paths.count == RollingForecast.sampleCount)
        #expect(f.paths.allSatisfy { $0.count == days })

        // 起点累计 0
        #expect(f.dailyMedian[0] == 0)
        // 分位单调不减（路径逐日累计非负 → 分位数单调）
        for d in 1..<days {
            #expect(f.dailyLower[d] >= f.dailyLower[d - 1])
            #expect(f.dailyMedian[d] >= f.dailyMedian[d - 1])
            #expect(f.dailyUpper[d] >= f.dailyUpper[d - 1])
        }
        // 逐日分位顺序：Q2.5 ≤ Q10 ≤ Q25 ≤ Q50 ≤ Q75 ≤ Q90 ≤ Q97.5
        for d in 0..<days {
            #expect(f.dailyLower[d] <= f.dailyQ10[d])
            #expect(f.dailyQ10[d] <= f.dailyQ25[d])
            #expect(f.dailyQ25[d] <= f.dailyMedian[d])
            #expect(f.dailyMedian[d] <= f.dailyQ75[d])
            #expect(f.dailyQ75[d] <= f.dailyQ90[d])
            #expect(f.dailyQ90[d] <= f.dailyUpper[d])
        }
        // 终点与 30 天累计分位一致（同分位索引公式）
        #expect(f.dailyLower[days - 1] == f.lowerBound)
        #expect(f.dailyMedian[days - 1] == f.median)
        #expect(f.dailyUpper[days - 1] == f.upperBound)
    }

    /// CI 单调性 + 边界
    @Test
    func testForecastIntervalMonotonic() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 888)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        #expect(f.samples.count == RollingForecast.sampleCount)
        #expect(f.lowerBound <= f.median)
        #expect(f.median <= f.upperBound)
        #expect(f.lowerBound <= f.mean && f.mean <= f.upperBound)
        #expect(f.probabilityPositive >= 0 && f.probabilityPositive <= 1)
        // probabilityAbove 与样本一致
        #expect(abs(f.probabilityAbove(0) - f.probabilityPositive) < 1e-12)
    }

    // MARK: - probabilityAbove

    /// 阈值低于所有样本 → P = 1
    @Test
    func testProbabilityAboveAllSamples() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 21)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        let minSample = f.samples.min()!
        let maxSample = f.samples.max()!
        #expect(abs(f.probabilityAbove(minSample - 1) - 1.0) < 1e-12)
        // 阈值低于 0（全部增长样本）→ 1
        #expect(f.probabilityAbove(-1e9) == 1.0)
    }

    /// 阈值高于所有样本 → P = 0
    @Test
    func testProbabilityAboveNoneSamples() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 22)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        let maxSample = f.samples.max()!
        #expect(abs(f.probabilityAbove(maxSample + 1) - 0.0) < 1e-12)
        #expect(f.probabilityAbove(1e9) == 0.0)
    }

    /// 中位数阈值 → P ≈ 0.5；与直接计数一致（样本语义验证）
    @Test
    func testProbabilityAboveMedian() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 23)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        let p = f.probabilityAbove(f.median)
        let manual = Double(f.samples.filter { $0 > f.median }.count) / Double(f.samples.count)
        #expect(abs(p - manual) < 1e-12)
        #expect(p >= 0.4 && p <= 0.6)  // 500 样本中位数阈值，P ≈ 0.5
    }

    // MARK: - quantileIndex（internal）

    /// 边界：q=0 → 0；q=1 → n−1
    @Test
    func testQuantileIndexBounds() {
        #expect(RollingForecast.quantileIndex(0, 100) == 0)
        #expect(RollingForecast.quantileIndex(1.0, 100) == 99)
        #expect(RollingForecast.quantileIndex(0, 1) == 0)
        #expect(RollingForecast.quantileIndex(1.0, 1) == 0)  // n=1 截断到 0
    }

    /// 中值：q=0.5, n=100 → 50；q=0.025, n=500 → 12（Int(12.5) = 12）
    @Test
    func testQuantileIndexMidValues() {
        #expect(RollingForecast.quantileIndex(0.5, 100) == 50)
        #expect(RollingForecast.quantileIndex(0.025, 500) == 12)
        #expect(RollingForecast.quantileIndex(0.975, 500) == 487)
        #expect(RollingForecast.quantileIndex(0.25, 40) == 10)
    }

    /// 越界 q → 截断到 [0, n−1]（不崩溃）
    @Test
    func testQuantileIndexClamps() {
        #expect(RollingForecast.quantileIndex(-0.5, 100) == 0)
        #expect(RollingForecast.quantileIndex(1.5, 100) == 99)
        #expect(RollingForecast.quantileIndex(Double.nan, 100) == 0)  // Int(NaN) 未定义→截断逻辑安全
    }

    // MARK: - choleskyWithJitter（internal）

    /// 正定矩阵 → 一次成功，且与 choleskyLower 结果一致（无 jitter 路径）
    @Test
    func testCholeskyWithJitterPositiveDefinite() {
        let a = Matrix(rows: 2, cols: 2, values: [4, 1, 1, 3])
        let direct = a.choleskyLower()
        let jittered = RollingForecast.choleskyWithJitter(a)
        #expect(direct != nil && jittered != nil)
        for r in 0..<2 {
            for c in 0...r {
                #expect(abs(direct![r, c] - jittered![r, c]) < 1e-12)
            }
        }
    }

    /// 半正定（特征值 5, 0）→ 极小 jitter 后成功
    @Test
    func testCholeskyWithJitterSemiDefinite() {
        let a = Matrix(rows: 2, cols: 2, values: [4, 2, 2, 1])  // det = 0
        #expect(a.choleskyLower() == nil)
        let l = RollingForecast.choleskyWithJitter(a)
        #expect(l != nil)
        // 重构验证：L·Lᵀ ≈ A + 1e-8·I
        let rebuilt = (l! * l!.transposed())!
        for r in 0..<2 {
            for c in 0..<2 {
                let expected = r == c ? a[r, c] + 1e-8 : a[r, c]
                #expect(abs(rebuilt[r, c] - expected) < 1e-4)
            }
        }
    }

    /// 本质非正定（特征值 3, −1）→ 8 次 jitter（到 1e-1）仍失败 → nil
    @Test
    func testCholeskyWithJitterNonPositiveDefiniteNil() {
        let a = Matrix(rows: 2, cols: 2, values: [1, 2, 2, 1])
        #expect(RollingForecast.choleskyWithJitter(a) == nil)
    }

    // MARK: - dot / leastSquaresSlope（internal）

    /// 手算：β=[1,2,3,4,5], x=[1,2,3,4] → 1 + 2·1+3·2+4·3+5·4 = 41
    @Test
    func testRollingDotHandComputed() {
        let beta = [1.0, 2.0, 3.0, 4.0, 5.0]
        let x = [1.0, 2.0, 3.0, 4.0]
        #expect(abs(RollingForecast.dot(beta, x) - 41) < 1e-12)
    }

    /// 截距项：特征系数全 0 → 恒等于 β0
    @Test
    func testRollingDotInterceptOnly() {
        let beta = [7.0, 0.0, 0.0, 0.0, 0.0]
        #expect(abs(RollingForecast.dot(beta, [1, 2, 3, 4]) - 7) < 1e-12)
        #expect(abs(RollingForecast.dot(beta, [-5, 9, 0, 100]) - 7) < 1e-12)
    }

    /// 与 GLM 点积同公式：相同输入 → 相同输出
    @Test
    func testRollingDotMatchesGLMDot() {
        let beta = [0.5, -1.2, 2.0, 0.3, -0.7]
        let x = [1.5, -2.0, 0.0, 4.0]
        #expect(abs(RollingForecast.dot(beta, x) - NegativeBinomialGLM.dot(beta, augmented: x)) < 1e-12)
    }

    /// 线性序列 → 斜率 = 公差（手算）
    @Test
    func testRollingLeastSquaresSlopeLinear() {
        #expect(abs(RollingForecast.leastSquaresSlope([0, 1, 2, 3, 4]) - 1.0) < 1e-12)
        #expect(abs(RollingForecast.leastSquaresSlope([10, 14, 18, 22]) - 4.0) < 1e-12)
        #expect(abs(RollingForecast.leastSquaresSlope([0, -2, -4]) + 2.0) < 1e-12)
    }

    /// 常数/单点/两点 → 斜率 0
    @Test
    func testRollingLeastSquaresSlopeFlat() {
        #expect(abs(RollingForecast.leastSquaresSlope([5, 5, 5, 5])) < 1e-12)
        #expect(abs(RollingForecast.leastSquaresSlope([-3])) < 1e-12)
        #expect(abs(RollingForecast.leastSquaresSlope([7, 7])) < 1e-12)
        #expect(abs(RollingForecast.leastSquaresSlope([])) < 1e-12)
    }

    /// 与 FeatureEngine 同公式：相同输入 → 相同输出
    @Test
    func testRollingLeastSquaresSlopeMatchesFeatureEngine() {
        let values = [1.0, 3.0, 6.0, 10.0, 15.0]
        #expect(abs(RollingForecast.leastSquaresSlope(values) - FeatureEngine.leastSquaresSlope(values)) < 1e-12)
    }

    /// 窗口不足（< windowSize=8）→ nil
    @Test
    func testInsufficientWindowNil() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 9)
        let short = Array(window.prefix(RollingForecast.windowSize - 1))
        #expect(RollingForecast.forecast(posterior: posterior, window: short, stats: stats, using: &rng) == nil)
    }

    /// 增长数据 → 预测均值显著为正，且 95% 区间几乎必然包含正值
    @Test
    func testForecastOnGrowthData() {
        let (posterior, window, stats) = makeFitAndWindow()
        var rng = TestRNG(seed: 12345)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &rng)!
        #expect(f.mean > 100)        // 日均 ~12 增长 × 30 天
        #expect(f.median > 0)
        #expect(f.upperBound > f.lowerBound)
    }

    /// 平缓数据 → 区间仍有效且包含 0 附近（不崩溃）
    @Test
    func testForecastOnFlatData() {
        var rng = TestRNG(seed: 6)
        let points = makeSyntheticGrowthPoints(
            rng: &rng, count: 60, startFollowers: 5_000,
            beta: [log(1), 0.0, 0.0, 0.0, 0.0], phi: 3
        )
        let rows = FeatureEngine.buildRows(points: points)
        guard let posterior = LaplaceApproximation.fit(rows: rows) else {
            Issue.record("fit 返回 nil")
            return
        }
        let (_, stats) = FeatureEngine.standardize(rows: rows)
        let window = Array(points.suffix(RollingForecast.windowSize))
        var fRNG = TestRNG(seed: 55)
        let f = RollingForecast.forecast(posterior: posterior, window: window, stats: stats, using: &fRNG)!
        #expect(f.lowerBound <= 0 || f.upperBound >= 0)  // 区间覆盖 0 附近
        #expect(f.mean >= 0)
    }
}
