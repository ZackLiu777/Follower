//
//  NegativeBinomialGLM.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）负二项 GLM：
//  对数后验（负二项似然 + 正则化先验）、解析梯度（digamma）、数值 Hessian。
//
//  参数向量 θ = [β0(截距), β1...β4(特征), logφ] — 共 6 维（v0.16 删共线特征）。
//  logφ 参数化保证 φ > 0 恒成立。
//
//  设计决策：一阶导数用解析式（含 digamma），二阶导数用数值中心差分
//  （对解析梯度差分）— 避免 trigamma 推导错误风险；6 维 × 12 次梯度评估
//  每次 O(n·d) 运算，毫秒级，数值 Hessian 精度足够牛顿收敛。
//

import Foundation

/// 负二项回归模型：似然 + 先验 + 梯度 + Hessian（全部静态纯函数）
enum NegativeBinomialGLM {
    /// 参数维度：截距 + 4 特征 + logφ
    static let parameterCount = 6
    /// 特征维度（与 FeatureEngine.featureCount 一致）
    static let featureCount = 4
    /// 先验：β ~ Normal(0, 1)（正则化防过拟合）；φ ~ Gamma(2, rate: 0.1)
    static let priorBetaStd = 1.0
    static let priorPhiShape = 2.0
    static let priorPhiRate = 0.1

    /// 单行对数似然（负二项密度，参数 θ，特征向量 x 前插截距 1）
    static func logLikelihood(params: [Double], features: [Double], target: Int) -> Double {
        let beta = Array(params[0..<5])
        let phi = exp(params[5])
        let mu = exp(dot(beta, augmented: features))
        return negBinomialLogPDF(y: target, mu: mu, phi: phi)
    }

    /// 对数后验（目标函数，牛顿法最大化）
    static func logPosterior(params: [Double], rows: [FeatureRow]) -> Double {
        guard params.count == parameterCount else { return -Double.infinity }
        var total = 0.0
        for row in rows {
            total += logLikelihood(params: params, features: row.features, target: row.target)
        }
        // 先验：β1...β4 ~ N(0,1)（截距不正则），φ ~ Gamma(2, 0.1)
        let phi = exp(params[5])
        for k in 1..<5 {
            let b = params[k]
            total += -0.5 * b * b / (priorBetaStd * priorBetaStd)
        }
        total += (priorPhiShape - 1) * log(phi) - priorPhiRate * phi
        return total
    }

    /// 解析梯度（负二项 + 先验）。
    /// 推导：∂logPDF/∂μ = y/μ − (y+φ)/(μ+φ)，链式 × μ·xₖ → (y − μ(y+φ)/(μ+φ))·xₖ
    ///       ∂logPDF/∂logφ = [ψ(y+φ) − ψ(φ) + log(φ/(φ+μ)) + 1 − (y+φ)/(μ+φ)]·φ
    static func gradient(params: [Double], rows: [FeatureRow]) -> [Double] {
        guard params.count == parameterCount else { return [] }
        var grad = [Double](repeating: 0, count: parameterCount)
        let beta = Array(params[0..<5])
        let phi = exp(params[5])

        for row in rows {
            let mu = exp(dot(beta, augmented: row.features))
            let y = Double(row.target)
            let sum = mu + phi

            // d/dβₖ
            let base = y - mu * (y + phi) / sum
            grad[0] += base
            for k in 1..<5 {
                grad[k] += base * row.features[k - 1]
            }
            // d/dlogφ
            grad[5] += (digamma(y + phi) - digamma(phi) + log(phi / sum) + 1 - (y + phi) / sum) * phi
        }
        // 先验梯度
        for k in 1..<5 {
            grad[k] += -params[k] / (priorBetaStd * priorBetaStd)
        }
        grad[5] += (priorPhiShape - 1) - priorPhiRate * phi
        return grad
    }

    /// 数值 Hessian — 对解析梯度做中心差分（h = 1e-4），结果对称化。
    /// 参数为标准化空间 O(1) 尺度，固定步长数值稳定。
    static func hessian(params: [Double], rows: [FeatureRow]) -> Matrix {
        let n = parameterCount
        let h = 1e-4
        var H = Matrix(rows: n, cols: n)
        for j in 0..<n {
            var plus = params, minus = params
            plus[j] += h
            minus[j] -= h
            let gPlus = gradient(params: plus, rows: rows)
            let gMinus = gradient(params: minus, rows: rows)
            for i in 0..<n {
                H[i, j] = (gPlus[i] - gMinus[i]) / (2 * h)
            }
        }
        // 对称化（数值误差）
        for r in 0..<n {
            for c in 0..<r {
                let sym = (H[r, c] + H[c, r]) / 2
                H[r, c] = sym
                H[c, r] = sym
            }
        }
        return H
    }

    // MARK: - Internal 纯函数（单元测试直接覆盖，@testable import）

    /// 点积（x 前插截距 1）。
    /// 防御：x 维度不足（如空特征 = 仅截距项）时只累加可用维度，不越界崩溃。
    static func dot(_ beta: [Double], augmented x: [Double]) -> Double {
        var sum = beta[0]
        for k in 0..<min(beta.count - 1, x.count) {
            sum += beta[k + 1] * x[k]
        }
        return sum
    }
}
