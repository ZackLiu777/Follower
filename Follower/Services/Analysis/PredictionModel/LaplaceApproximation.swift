//
//  LaplaceApproximation.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）Laplace 近似：
//  牛顿法求 MAP（最大后验），Hessian 逆 → 后验高斯近似 N(θ*, (−H)⁻¹)。
//  确定性路径（无随机性）→ 单元测试可精确断言。
//
//  v0.16：步长减半回退修复 —— 原实现 10 次减半到 1/512 仍达不到
//  `stepLength < 1e-6` 阈值（死代码分支），牛顿步不升时整体返回 nil；
//  现改为记录最佳有限候选，减半结束无条件接受，保证迭代推进不整体失败。
//
//  v0.17：Hessian 符号修复（fit 在真实数据上恒 nil 的根因）——
//  对数后验对 β 全局凹 → Hessian 负定；Matrix.solve 仅支持正定 Cholesky。
//  原实现对 H 直接加正 jitter：λ 需盖过 |λmin|（mock 数据 ~107）才"正定"，
//  此时 (H+λI)⁻¹(−g) 为下降方向 → 所有步长后验不升 → 整体 nil；且协方差
//  求解对负定 H 加 1e-8 永远无法 dpotrf → 收敛后也必然 nil。
//  修复：牛顿步与协方差均对 A = −H（全元素取负）加 jitter 后 solve。
//

import Foundation

/// 后验高斯近似（Laplace）— θ ~ N(mean, covariance)，θ = [β0..β5, logφ]
struct PosteriorGaussian: Sendable {
    let mean: [Double]
    let covariance: Matrix
    /// 牛顿迭代收敛次数（诊断用）
    let iterations: Int
}

/// Laplace 近似拟合器 — 全静态纯函数（确定性）
enum LaplaceApproximation {
    /// 最小训练行数（冷启动阈值：少于该行数返回 nil）
    static let minRows = 30

    /// 拟合后验：牛顿法最大化对数后验，负 Hessian 逆 = 后验协方差
    static func fit(rows: [FeatureRow]) -> PosteriorGaussian? {
        guard rows.count >= minRows else { return nil }
        let n = NegativeBinomialGLM.parameterCount

        // 初始值：β = 0（μ = e⁰ = 1），logφ = log(5)
        var theta = [Double](repeating: 0, count: n)
        theta[n - 1] = log(5)

        let maxIterations = 100

        for iteration in 0..<maxIterations {
            let grad = NegativeBinomialGLM.gradient(params: theta, rows: rows)
            let H = NegativeBinomialGLM.hessian(params: theta, rows: rows)

            // 牛顿步：对数后验对 β 全局凹 → Hessian 负定。Δ = −H⁻¹·g。
            // 数值上对 A = −H（全元素取负）做 Cholesky（Matrix.solve 仅支持正定），
            // 病态时对角 jitter 倍增重试。对 H 直接加正 jitter 会让 A 需盖过
            // |λmin(H)| 才"正定"，此时 (H+λI)⁻¹(−g) 方向反转（下降）→ fit 整体 nil。
            var step: [Double]? = nil
            var lambda = 1e-8
            for _ in 0..<12 {
                var A = H
                for r in 0..<n {
                    for c in 0..<n { A[r, c] = -A[r, c] }
                    A[r, r] += lambda
                }
                if let s = A.solve(grad) {
                    step = s
                    break
                }
                lambda *= 10
            }
            guard let rawStep = step else { return nil }

            // 步长减半重试（v0.16：全部不升时接受最佳有限候选，不再整体失败）
            var applied = false
            var stepLength = 1.0
            var current = logPosterior(params: theta, rows: rows)
            // 记录有限值下最高的候选（NaN 防护 + 数值病态兜底）
            var fallback: [Double]? = nil
            var fallbackValue = current
            for _ in 0..<10 {
                let candidate = zip(theta, rawStep).map { $0 + stepLength * $1 }
                let value = logPosterior(params: candidate, rows: rows)
                if value.isFinite && value > current {
                    theta = candidate
                    current = value
                    applied = true
                    break
                }
                if value.isFinite && value > fallbackValue {
                    fallbackValue = value
                    fallback = candidate
                }
                stepLength *= 0.5
            }
            if !applied {
                // 所有减半水平后验都不升：接受最佳有限候选（保持迭代推进，
                // 防止病态牛顿步把整个 fit 打成 nil；小步长梯度下降方向必然有界）
                guard let fallback, fallbackValue.isFinite else { return nil }
                theta = fallback
                current = fallbackValue
            }

            // 收敛判定
            let maxDelta = zip(theta, rawStep).map { abs(stepLength * $1) }.max() ?? 0
            if maxDelta < 1e-6 * (1 + theta.map(abs).max()!) {
                // 用最终参数重算 Hessian；协方差 = (−H)⁻¹：
                // A = −H（全元素取负，正定）+ 小 jitter 防奇异，逐列 solve。
                // 注意：H 本身负定，对 H 直接加 jitter 做 dpotrf 必然失败。
                let finalH = NegativeBinomialGLM.hessian(params: theta, rows: rows)
                var A = finalH
                for r in 0..<n {
                    for c in 0..<n { A[r, c] = -A[r, c] }
                    A[r, r] += 1e-8
                }
                // 逐列求逆：solve(e_j) 得逆的第 j 列（行主序存放）
                var invValues = [Double](repeating: 0, count: n * n)
                for j in 0..<n {
                    var e = [Double](repeating: 0, count: n)
                    e[j] = 1
                    guard let x = A.solve(e) else { return nil }
                    for i in 0..<n {
                        invValues[i * n + j] = x[i]
                    }
                }
                var cov = Matrix(rows: n, cols: n, values: invValues)
                for r in 0..<n {
                    for c in 0..<r {
                        let sym = (cov[r, c] + cov[c, r]) / 2
                        cov[r, c] = sym
                        cov[c, r] = sym
                    }
                }
                return PosteriorGaussian(mean: theta, covariance: cov, iterations: iteration + 1)
            }
        }
        // 循环内收敛时已 return；到达此处 = 100 次未收敛 → 视为失败
        return nil
    }

    // MARK: - Private

    /// 当前参数下的对数后验（步长控制用）
    private static func logPosterior(params: [Double], rows: [FeatureRow]) -> Double {
        NegativeBinomialGLM.logPosterior(params: params, rows: rows)
    }
}
