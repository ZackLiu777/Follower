//
//  MatrixTests.swift
//  FollowerTests
//
//  预测模型矩阵工具测试：
//  转置/乘/乘向量、Cholesky 分解重构、线性求解往返、非正定 nil。
//

import Testing
import Foundation
@testable import Follower

struct MatrixTests {

    /// 转置：2×3 → 3×2，值按对角翻转
    @Test
    func testTranspose() {
        let a = Matrix(rows: 2, cols: 3, values: [1, 2, 3, 4, 5, 6])
        let t = a.transposed()
        #expect(t.rows == 3 && t.cols == 2)
        #expect(t[0, 0] == 1 && t[1, 0] == 2 && t[2, 0] == 3)
        #expect(t[0, 1] == 4 && t[1, 1] == 5 && t[2, 1] == 6)
    }

    /// 转置：方阵 3×3，对角不变、次对角翻转（t[r,c] == a[c,r]）
    @Test
    func testTransposeSquare() {
        let a = Matrix(rows: 3, cols: 3, values: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let t = a.transposed()
        #expect(t.rows == 3 && t.cols == 3)
        for r in 0..<3 {
            for c in 0..<3 {
                #expect(t[r, c] == a[c, r])
            }
        }
        // 两次转置回到原矩阵
        let back = t.transposed()
        for r in 0..<3 {
            for c in 0..<3 {
                #expect(back[r, c] == a[r, c])
            }
        }
    }

    /// 转置：1×4 行向量 → 4×1 列向量
    @Test
    func testTransposeRowVector() {
        let a = Matrix(rows: 1, cols: 4, values: [7, 8, 9, 10])
        let t = a.transposed()
        #expect(t.rows == 4 && t.cols == 1)
        for i in 0..<4 {
            #expect(t[i, 0] == Double(i + 7))
        }
    }

    /// 矩阵乘：手算 [[1,2],[3,4]] · [[5,6],[7,8]]
    @Test
    func testMatrixMultiply() {
        let a = Matrix(rows: 2, cols: 2, values: [1, 2, 3, 4])
        let b = Matrix(rows: 2, cols: 2, values: [5, 6, 7, 8])
        let c = (a * b)!
        #expect(abs(c[0, 0] - 19) < 1e-12)
        #expect(abs(c[0, 1] - 22) < 1e-12)
        #expect(abs(c[1, 0] - 43) < 1e-12)
        #expect(abs(c[1, 1] - 50) < 1e-12)
    }

    /// 尺寸不匹配 → nil
    @Test
    func testMatrixMultiplyMismatch() {
        let a = Matrix(rows: 2, cols: 3)
        let b = Matrix(rows: 2, cols: 2)
        #expect((a * b) == nil)
    }

    /// 非方阵相乘：2×3 · 3×2 → 2×2，手算验证
    @Test
    func testMatrixMultiplyRectangular() {
        let a = Matrix(rows: 2, cols: 3, values: [1, 2, 3, 4, 5, 6])
        let b = Matrix(rows: 3, cols: 2, values: [7, 8, 9, 10, 11, 12])
        let c = (a * b)!
        // [[1·7+2·9+3·11, 1·8+2·10+3·12],
        //  [4·7+5·9+6·11, 4·8+5·10+6·12]] = [[58, 64], [139, 154]]
        #expect(abs(c[0, 0] - 58) < 1e-12)
        #expect(abs(c[0, 1] - 64) < 1e-12)
        #expect(abs(c[1, 0] - 139) < 1e-12)
        #expect(abs(c[1, 1] - 154) < 1e-12)
    }

    /// 矩阵乘向量：[[1,2,3],[4,5,6]] · [1,1,1] = [6, 15]
    @Test
    func testMultiplyVector() {
        let a = Matrix(rows: 2, cols: 3, values: [1, 2, 3, 4, 5, 6])
        let v = a.multiplied(by: [1, 1, 1])!
        #expect(abs(v[0] - 6) < 1e-12 && abs(v[1] - 15) < 1e-12)
    }

    /// 向量维度不匹配（≠ 列数）→ nil
    @Test
    func testMultiplyVectorMismatch() {
        let a = Matrix(rows: 2, cols: 3)
        #expect(a.multiplied(by: [1, 2]) == nil)
        #expect(a.multiplied(by: [1, 2, 3, 4]) == nil)
        #expect(a.multiplied(by: []) == nil)
    }

    /// 单位矩阵乘任意向量 → 原向量；行向量 × 列向量 = 点积
    @Test
    func testMultiplyVectorIdentityAndDot() {
        let identity = Matrix(rows: 3, cols: 3, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
        let v = identity.multiplied(by: [3.5, -2.0, 9.0])!
        #expect(v == [3.5, -2.0, 9.0])

        // 1×3 行向量 · 3×1 列向量 → 标量点积
        let row = Matrix(rows: 1, cols: 3, values: [1, 2, 3])
        let dot = row.multiplied(by: [4, 5, 6])!
        #expect(dot.count == 1)
        #expect(abs(dot[0] - 32) < 1e-12)
    }

    /// Cholesky：[[4,2],[2,3]] → L = [[2,0],[1,√2]]，且 L·Lᵀ 重构 A
    @Test
    func testCholeskyReconstructs() {
        let a = Matrix(rows: 2, cols: 2, values: [4, 2, 2, 3])
        let l = a.choleskyLower()!
        #expect(abs(l[0, 0] - 2) < 1e-9)
        #expect(l[0, 1] == 0)
        #expect(abs(l[1, 0] - 1) < 1e-9)
        #expect(abs(l[1, 1] - sqrt(2)) < 1e-9)
        let rebuilt = (l * l.transposed())!
        for r in 0..<2 {
            for c in 0..<2 {
                #expect(abs(rebuilt[r, c] - a[r, c]) < 1e-9)
            }
        }
    }

    /// solve：A·x = b 手算 — [[4,2],[2,3]]·x = [10,8] → x = [1.75, 1.5]
    @Test
    func testSolveHandComputed() {
        let a = Matrix(rows: 2, cols: 2, values: [4, 2, 2, 3])
        let x = a.solve([10, 8])!
        #expect(abs(x[0] - 1.75) < 1e-9)
        #expect(abs(x[1] - 1.5) < 1e-9)
    }

    /// solve 往返：3×3 正定矩阵，解回代 A·x̂ ≈ b
    @Test
    func testSolveRoundTrip3x3() {
        let a = Matrix(rows: 3, cols: 3, values: [6, 2, 1, 2, 5, 1, 1, 1, 4])
        let b = [17.0, 12.0, 10.0]
        let x = a.solve(b)!
        // 回代验证（不依赖手算值）
        for r in 0..<3 {
            var sum = 0.0
            for c in 0..<3 {
                sum += a[r, c] * x[c]
            }
            #expect(abs(sum - b[r]) < 1e-8)
        }
    }

    /// 非正定矩阵（[[1,2],[2,1]]，特征值 3, −1）→ Cholesky nil → solve nil
    @Test
    func testNonPositiveDefiniteReturnsNil() {
        let a = Matrix(rows: 2, cols: 2, values: [1, 2, 2, 1])
        #expect(a.choleskyLower() == nil)
        #expect(a.solve([1, 1]) == nil)
    }

    /// 行列不一致矩阵 → nil
    @Test
    func testNonSquareCholeskyNil() {
        let a = Matrix(rows: 2, cols: 3)
        #expect(a.choleskyLower() == nil)
    }
}
