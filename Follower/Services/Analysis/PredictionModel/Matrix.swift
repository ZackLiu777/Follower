//
//  Matrix.swift
//  Follower
//
//  贝叶斯预测模型（PredictionModel）最小矩阵工具。
//  小矩阵（≤10×10）手写运算；Cholesky 分解用 Accelerate LAPACK（dpotrf），
//  正确性有保障；三角求解手写前向/后向替换。
//

import Foundation
import Accelerate

/// 行主序小矩阵 — 支持乘/转置/Cholesky 分解/线性求解
struct Matrix: Sendable {
    let rows: Int
    let cols: Int
    private(set) var values: [Double]

    /// 全零矩阵
    init(rows: Int, cols: Int, repeating value: Double = 0) {
        self.rows = rows
        self.cols = cols
        self.values = [Double](repeating: value, count: rows * cols)
    }

    /// 行主序 values 构造（数量必须匹配 rows×cols）
    init(rows: Int, cols: Int, values: [Double]) {
        precondition(values.count == rows * cols, "Matrix values count mismatch")
        self.rows = rows
        self.cols = cols
        self.values = values
    }

    subscript(row: Int, col: Int) -> Double {
        get { values[row * cols + col] }
        set { values[row * cols + col] = newValue }
    }

    /// 转置
    func transposed() -> Matrix {
        var out = Matrix(rows: cols, cols: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                out[c, r] = self[r, c]
            }
        }
        return out
    }

    /// 矩阵乘（尺寸不匹配返回 nil）
    static func * (a: Matrix, b: Matrix) -> Matrix? {
        guard a.cols == b.rows else { return nil }
        var out = Matrix(rows: a.rows, cols: b.cols)
        for r in 0..<a.rows {
            for c in 0..<b.cols {
                var sum = 0.0
                for k in 0..<a.cols {
                    sum += a[r, k] * b[k, c]
                }
                out[r, c] = sum
            }
        }
        return out
    }

    /// 矩阵乘向量（列数不匹配返回 nil）
    func multiplied(by vector: [Double]) -> [Double]? {
        guard vector.count == cols else { return nil }
        var out = [Double](repeating: 0, count: rows)
        for r in 0..<rows {
            var sum = 0.0
            for c in 0..<cols {
                sum += self[r, c] * vector[c]
            }
            out[r] = sum
        }
        return out
    }

    /// 对称正定矩阵的 Cholesky 分解（L·Lᵀ = A）→ 返回下三角 L。
    /// 使用 Accelerate LAPACK dpotrf（'L' 模式）；非正定返回 nil。
    /// 调用方应在 Hessian 上加对角 jitter 后再调用。
    func choleskyLower() -> Matrix? {
        guard rows == cols, rows > 0 else { return nil }
        let n = rows

        // LAPACK 列主序输入（对称矩阵：colMajor[r + c·n] = A[r, c]）
        var a = [Double](repeating: 0, count: n * n)
        for c in 0..<n {
            for r in 0..<n {
                a[c * n + r] = self[r, c]
            }
        }

        var uplo: Int8 = 76  // 'L'
        var dim = Int32(n)
        var lda = Int32(n)
        var info: Int32 = 0
        _ = a.withUnsafeMutableBufferPointer { ptr in
            dpotrf_(&uplo, &dim, ptr.baseAddress!, &lda, &info)
        }
        guard info == 0 else { return nil }  // info > 0 → 第 info 个主元非正（非正定）

        // 取列主序 L 的下三角 → 行主序下三角
        var l = Matrix(rows: n, cols: n)
        for r in 0..<n {
            for c in 0...r {
                l[r, c] = a[c * n + r]
            }
        }
        return l
    }

    /// 解 A·x = b（A 对称正定）— Cholesky 分解 + 前向/后向替换
    func solve(_ b: [Double]) -> [Double]? {
        guard let l = choleskyLower() else { return nil }
        let n = rows

        // 前向：L·y = b
        var y = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var sum = b[i]
            for j in 0..<i {
                sum -= l[i, j] * y[j]
            }
            y[i] = sum / l[i, i]
        }
        // 后向：Lᵀ·x = y
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = y[i]
            for j in (i + 1)..<n {
                sum -= l[j, i] * x[j]
            }
            x[i] = sum / l[i, i]
        }
        return x
    }
}
