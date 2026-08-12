//
//  GLMGradientTests.swift
//  FollowerTests
//
//  负二项 GLM 梯度验证：
//  解析梯度 vs 对数后验数值中心差分（相对容差 1e-4）；
//  Hessian 对称性（3 组参数点）。
//

import Testing
import Foundation
@testable import Follower

struct GLMGradientTests {

    /// 合成 60 点（→ 52 特征行），真值 β=[1.0, 0.3, 0, −0.2, 0.05]，φ=8
    private func makeRows() -> [FeatureRow] {
        var rng = TestRNG(seed: 2026)
        let points = makeSyntheticGrowthPoints(
            rng: &rng, count: 60, startFollowers: 8_000,
            beta: [1.0, 0.3, 0.0, -0.2, 0.05], phi: 8
        )
        return FeatureEngine.buildRows(points: points)
    }

    /// 解析梯度 vs 数值梯度（中心差分 h=1e-6），相对容差 1e-4
    @Test
    func testAnalyticGradientMatchesNumeric() {
        let rows = makeRows()
        let testPoints: [[Double]] = [
            [0.5, 0.1, -0.05, 0.1, 0.02, log(5)],   // 随机起点
            [1.0, 0.3, 0.0, -0.2, 0.05, log(8)],    // 真值附近
            [-0.3, 0.2, 0.1, -0.1, 0.0, log(2)],    // 偏离点
        ]
        let h = 1e-6
        for theta in testPoints {
            let analytic = NegativeBinomialGLM.gradient(params: theta, rows: rows)
            #expect(analytic.count == NegativeBinomialGLM.parameterCount)

            for j in 0..<theta.count {
                var plus = theta, minus = theta
                plus[j] += h
                minus[j] -= h
                let numeric = (NegativeBinomialGLM.logPosterior(params: plus, rows: rows)
                    - NegativeBinomialGLM.logPosterior(params: minus, rows: rows)) / (2 * h)
                let scale = max(1, abs(analytic[j]), abs(numeric))
                #expect(abs(analytic[j] - numeric) < 1e-4 * scale,
                        "grad[\(j)] analytic=\(analytic[j]) numeric=\(numeric)")
            }
        }
    }

    /// Hessian 对称性（3 组参数点）
    @Test
    func testHessianSymmetric() {
        let rows = makeRows()
        let testPoints: [[Double]] = [
            [0.5, 0.1, -0.05, 0.1, 0.02, log(5)],
            [1.0, 0.3, 0.0, -0.2, 0.05, log(8)],
            [-0.3, 0.2, 0.1, -0.1, 0.0, log(2)],
        ]
        for theta in testPoints {
            let H = NegativeBinomialGLM.hessian(params: theta, rows: rows)
            #expect(H.rows == NegativeBinomialGLM.parameterCount)
            #expect(H.cols == NegativeBinomialGLM.parameterCount)
            for r in 0..<H.rows {
                for c in 0..<H.cols {
                    let scale = max(1, abs(H[r, c]), abs(H[c, r]))
                    #expect(abs(H[r, c] - H[c, r]) < 1e-8 * scale,
                            "H[\(r),\(c)]=\(H[r,c]) H[\(c),\(r)]=\(H[c,r])")
                }
            }
        }
    }

    /// MAP 处梯度应接近 0（一阶最优性条件）
    @Test
    func testGradientZeroAtMAP() {
        var rng = TestRNG(seed: 314)
        let points = makeSyntheticGrowthPoints(
            rng: &rng, count: 80, startFollowers: 12_000,
            beta: [1.5, 0.4, 0.0, -0.1, 0.02], phi: 12
        )
        let rows = FeatureEngine.buildRows(points: points)
        guard let posterior = LaplaceApproximation.fit(rows: rows) else {
            Issue.record("fit 返回 nil")
            return
        }
        let grad = NegativeBinomialGLM.gradient(params: posterior.mean, rows: rows)
        // 梯度分量与参数量级做相对比较（参数 O(1)，梯度应显著小于训练行数级）
        for (k, g) in grad.enumerated() {
            let scale = max(1, Double(rows.count) / 10)
            #expect(abs(g) < scale,
                    "MAP 处梯度分量 \(k) = \(g) 应接近 0")
        }
    }

    // MARK: - logLikelihood 直接测试

    /// 手算：θ=[0,0,0,0,0,log5] → μ=1, φ=5；y=0 时
    /// logΓ(5)−logΓ(5)−logΓ(1)+5·(log5−log6) = 5·log(5/6)
    @Test
    func testLogLikelihoodHandComputed() {
        let params = [0.0, 0, 0, 0, 0, log(5)]
        let p0 = NegativeBinomialGLM.logLikelihood(params: params, features: [1, 2, 3, 4], target: 0)
        #expect(abs(p0 - 5 * log(5.0 / 6.0)) < 1e-9)

        // y=1：logΓ(6)−logΓ(5) = log(5)；+ 1·(log1 − log6) = −log6
        let p1 = NegativeBinomialGLM.logLikelihood(params: params, features: [1, 2, 3, 4], target: 1)
        let expected = log(5) + 5 * log(5.0 / 6.0) - log(6.0)
        #expect(abs(p1 - expected) < 1e-9)
    }

    /// logLikelihood 与 Distributions.negBinomialLogPDF 完全一致（同一公式封装）
    @Test
    func testLogLikelihoodMatchesNegBinomialPDF() {
        let cases: [(beta: [Double], features: [Double], y: Int)] = [
            ([1.0, 0.2, -0.1, 0.05, 0.0], [2.0, 1.0, -3.0, 4.0], 5),
            ([0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], 0),
            ([-2.0, 0.5, 1.0, -0.5, 0.25], [1.0, -1.0, 2.0, -2.0], 12),
        ]
        for c in cases {
            // 构造 μ = exp(b0 + Σ b_k·x_{k−1})
            var eta = c.beta[0]
            for k in 1..<5 { eta += c.beta[k] * c.features[k - 1] }
            let params = c.beta + [log(8.0)]
            let mu = exp(eta)
            let direct = negBinomialLogPDF(y: c.y, mu: mu, phi: 8)
            let viaGLM = NegativeBinomialGLM.logLikelihood(params: params, features: c.features, target: c.y)
            #expect(abs(viaGLM - direct) < 1e-12)
        }
    }

    /// 特征维度不足 / 参数维度不足 → −∞ 或退化为截距项
    @Test
    func testLogLikelihoodDegenerateParams() {
        // 空特征（无特征行语义）：μ = exp(β0)，仍是合法密度
        let params = [2.0, 0, 0, 0, 0, log(5)]
        let p = NegativeBinomialGLM.logLikelihood(params: params, features: [], target: 3)
        let mu = exp(2.0)
        #expect(abs(p - negBinomialLogPDF(y: 3, mu: mu, phi: 5)) < 1e-12)
    }

    // MARK: - logPosterior 直接测试

    /// 空行 → 纯先验：−0.5·Σβ₁..β₄² + (shape−1)·logφ − rate·φ
    @Test
    func testLogPosteriorEmptyRowsIsPrior() {
        let params = [0.5, 0.2, -0.1, 0.3, 0.0, log(10.0)]
        let posterior = NegativeBinomialGLM.logPosterior(params: params, rows: [])
        let prior = -0.5 * (0.04 + 0.01 + 0.09 + 0.0) + log(10.0) - 0.1 * 10.0
        #expect(abs(posterior - prior) < 1e-12)
    }

    /// 截距不正则：β0 任意大，先验项不含 β0²
    @Test
    func testLogPosteriorInterceptUnregularized() {
        // 两参数只差 β0（+5）：β1..β4 与 φ 相同 → 先验差值仅来自似然项
        let rows = [
            FeatureRow(features: [1, 2, 3, 4], target: 2),
            FeatureRow(features: [-1, 0, 1, -2], target: 5),
        ]
        let a = [0.0, 0.1, -0.2, 0.3, 0.0, log(5.0)]
        let b = [5.0, 0.1, -0.2, 0.3, 0.0, log(5.0)]
        let la = NegativeBinomialGLM.logPosterior(params: a, rows: rows)
        let lb = NegativeBinomialGLM.logPosterior(params: b, rows: rows)
        // 差值应等于两参数截距下似然差（先验对 β0 无贡献）
        let diff = lb - la
        #expect(diff.isFinite && diff != 0)
        // 对称检查：把 β0 换回 0，两式先验项相等
        let pa = NegativeBinomialGLM.logPosterior(params: a, rows: [])
        let pb = NegativeBinomialGLM.logPosterior(params: b, rows: [])
        #expect(abs(pa - pb) < 1e-12)
    }

    /// logPosterior = Σ logLikelihood + 手算先验（一致性验证）
    @Test
    func testLogPosteriorEqualsLikelihoodPlusPrior() {
        let rows = [
            FeatureRow(features: [1.5, 2.0, -1.0, 0.5], target: 4),
            FeatureRow(features: [-0.5, 1.0, 2.0, -3.0], target: 0),
            FeatureRow(features: [0.0, 0.0, 0.0, 0.0], target: 7),
        ]
        let params = [0.8, 0.2, -0.3, 0.1, 0.05, log(7.0)]
        let viaGLM = NegativeBinomialGLM.logPosterior(params: params, rows: rows)

        var expected = 0.0
        for row in rows {
            expected += NegativeBinomialGLM.logLikelihood(params: params, features: row.features, target: row.target)
        }
        let phi = exp(params[5])
        for k in 1..<5 {
            expected += -0.5 * params[k] * params[k]
        }
        expected += log(phi) - 0.1 * phi
        #expect(abs(viaGLM - expected) < 1e-12)
    }

    // MARK: - gradient 空行（纯先验梯度）

    /// 空行 → 梯度 = 先验梯度：grad[0]=0, grad[k]=−βₖ, grad[5]=1−0.1φ
    @Test
    func testGradientEmptyRowsIsPriorGradient() {
        let params = [0.5, 0.2, -0.1, 0.3, 0.0, log(10.0)]
        let grad = NegativeBinomialGLM.gradient(params: params, rows: [])
        #expect(grad.count == NegativeBinomialGLM.parameterCount)
        #expect(abs(grad[0]) < 1e-12)      // 截距无先验
        #expect(abs(grad[1] + 0.2) < 1e-12) // −β1
        #expect(abs(grad[2] - 0.1) < 1e-12) // −β2 = +0.1
        #expect(abs(grad[3] + 0.3) < 1e-12) // −β3
        #expect(abs(grad[4]) < 1e-12)       // −β4 = 0
        #expect(abs(grad[5]) < 1e-12)       // 1 − 0.1·10 = 0
    }

    // MARK: - hessian 直接测试

    /// Hessian 负定（严格凹）：任意点全部对角元 < 0
    @Test
    func testHessianNegativeDefiniteDiagonal() {
        let rows = makeRows()
        let testPoints: [[Double]] = [
            [0.5, 0.1, -0.05, 0.1, 0.02, log(5)],
            [1.0, 0.3, 0.0, -0.2, 0.05, log(8)],
            [-0.3, 0.2, 0.1, -0.1, 0.0, log(2)],
        ]
        for theta in testPoints {
            let H = NegativeBinomialGLM.hessian(params: theta, rows: rows)
            for k in 0..<H.rows {
                #expect(H[k, k] < 0, "θ=\(theta) 对角 \(k) = \(H[k, k]) 应为负")
            }
        }
    }

    /// Hessian 与对数后验二阶中心差分一致（实现正确性直接验证，h=1e-4 同实现）
    @Test
    func testHessianMatchesNumericSecondDifference() {
        let rows = makeRows()
        let theta = [0.7, -0.1, 0.2, 0.05, -0.03, log(6.0)]
        let H = NegativeBinomialGLM.hessian(params: theta, rows: rows)
        let h = 1e-4
        for j in 0..<theta.count {
            var plus = theta, minus = theta
            plus[j] += h
            minus[j] -= h
            let fPlus = NegativeBinomialGLM.logPosterior(params: plus, rows: rows)
            let fMinus = NegativeBinomialGLM.logPosterior(params: minus, rows: rows)
            let f0 = NegativeBinomialGLM.logPosterior(params: theta, rows: rows)
            let secondDiff = (fPlus - 2 * f0 + fMinus) / (h * h)
            let scale = max(1, abs(H[j, j]), abs(secondDiff))
            #expect(abs(H[j, j] - secondDiff) < 1e-2 * scale,
                    "H[\(j),\(j)]=\(H[j,j]) secondDiff=\(secondDiff)")
        }
    }

    /// 空行 Hessian = 先验 Hessian：β 对角 −1，logφ 对角 −rate·φ
    @Test
    func testHessianEmptyRowsIsPriorCurvature() {
        let theta = [0.0, 0.2, -0.1, 0.3, 0.0, log(10.0)]
        let H = NegativeBinomialGLM.hessian(params: theta, rows: [])
        #expect(H.rows == NegativeBinomialGLM.parameterCount)
        #expect(abs(H[0, 0]) < 1e-10)          // 截距无先验曲率
        for k in 1..<5 {
            #expect(abs(H[k, k] + 1) < 1e-10, "β\(k) 先验曲率应为 −1")
        }
        // −rate·φ = −1；logφ 维用中心差分（h=1e-4），FD 噪声 h²·f'''/6 ≈ 1.7e-9，
        // 容差取 1e-8（其余条目为线性/常数 → 差分精确，仍可用 1e-10）
        #expect(abs(H[5, 5] + 0.1 * 10.0) < 1e-8)
        // 非对角全 0（先验无交叉项）
        #expect(abs(H[1, 2]) < 1e-10 && abs(H[3, 5]) < 1e-10)
    }

    // MARK: - dot（internal，x 前插截距 1）

    /// 手算：β=[1,2,3,4,5], x=[1,2,3,4] → 1 + 2·1+3·2+4·3+5·4 = 41
    @Test
    func testDotHandComputed() {
        let beta = [1.0, 2.0, 3.0, 4.0, 5.0]
        let x = [1.0, 2.0, 3.0, 4.0]
        #expect(abs(NegativeBinomialGLM.dot(beta, augmented: x) - 41) < 1e-12)
    }

    /// 截距 = 特征加权和 + 截距；零特征系数 → 恒等于截距
    @Test
    func testDotInterceptOnly() {
        // 特征系数全 0：结果 = β0，与 x 无关
        let beta = [7.0, 0.0, 0.0, 0.0, 0.0]
        #expect(abs(NegativeBinomialGLM.dot(beta, augmented: [1, 2, 3, 4]) - 7) < 1e-12)
        #expect(abs(NegativeBinomialGLM.dot(beta, augmented: [-5, 9, 0, 100]) - 7) < 1e-12)
    }

    /// 与 μ = exp(dot) 的链接语义一致：x 全 0（标准化后特征为 0）→ μ = e^β0
    @Test
    func testDotZeroFeatures() {
        let beta = [-1.5, 0.3, 0.2, -0.1, 0.4]
        let dot = NegativeBinomialGLM.dot(beta, augmented: [0, 0, 0, 0])
        #expect(abs(dot - (-1.5)) < 1e-12)
        #expect(abs(exp(dot) - exp(-1.5)) < 1e-12)
    }
}
