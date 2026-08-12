//
//  SeededRandomTests.swift
//  FollowerTests
//
//  确定性伪随机源（LCG）单元测试 — 同种子序列可复现、值域正确、
//  范围方法边界、pick / chance 行为。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for SeededRandom — determinism, value ranges, and boundary behavior
struct SeededRandomTests {

    // MARK: - 确定性

    /// 相同种子 → 前 5 个 next() 序列完全相同
    @Test
    func testSameSeedProducesIdenticalSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        let seqA = (0..<5).map { _ in a.next() }
        let seqB = (0..<5).map { _ in b.next() }
        #expect(seqA == seqB)
    }

    /// 不同种子 → 序列不同（首个值不同）
    @Test
    func testDifferentSeedProducesDifferentSequence() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        #expect(a.next() != b.next())
    }

    /// seed = 0 → 使用黄金比例常数兜底，仍产生确定序列
    @Test
    func testZeroSeedFallsBackToGoldenRatio() {
        var a = SeededRandom(seed: 0)
        var b = SeededRandom(seed: 0)
        let first = a.next()
        let firstB = b.next()
        #expect(first == firstB)
        #expect(first >= 0 && first < 1)
    }

    // MARK: - next() 值域

    /// next() 始终落在 [0, 1) 区间（1000 次采样）
    @Test
    func testNextAlwaysInUnitRange() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<1000 {
            let v = rng.next()
            #expect(v >= 0.0)
            #expect(v < 1.0)
        }
    }

    // MARK: - int(in:)

    /// int(in:) 闭区间 — 采样全部落在范围内
    @Test
    func testIntWithinClosedRange() {
        var rng = SeededRandom(seed: 3)
        for _ in 0..<500 {
            let v = rng.int(in: 10...20)
            #expect(v >= 10 && v <= 20)
        }
    }

    /// 单值区间 [5, 5] → 恒返回 5
    @Test
    func testIntSingleValueRange() {
        var rng = SeededRandom(seed: 9)
        for _ in 0..<10 {
            #expect(rng.int(in: 5...5) == 5)
        }
    }

    // MARK: - double(in:)

    /// double(in:) 半开区间 — 采样落在 [lo, hi) 且覆盖多个值
    @Test
    func testDoubleWithinHalfOpenRange() {
        var rng = SeededRandom(seed: 11)
        var values: [Double] = []
        for _ in 0..<500 {
            let v = rng.double(in: 0.0..<1.0)
            #expect(v >= 0.0 && v < 1.0)
            values.append(v)
        }
        // 采样应覆盖区间（非全 0）
        // （Swift Testing 宏对 #expect 内 $0 闭包有限制，先取出再断言）
        let hasHighValue = values.contains { $0 > 0.5 }
        #expect(hasHighValue)
    }

    // MARK: - pick

    /// 单元素数组 → 恒返回该元素
    @Test
    func testPickSingleElement() {
        var rng = SeededRandom(seed: 5)
        for _ in 0..<10 {
            #expect(rng.pick([42]) == 42)
        }
    }

    /// 多元素数组 → 返回数组内元素
    @Test
    func testPickFromMultipleElements() {
        var rng = SeededRandom(seed: 8)
        let items = ["a", "b", "c", "d"]
        for _ in 0..<200 {
            let picked = rng.pick(items)
            #expect(items.contains(picked))
        }
    }

    // MARK: - chance

    /// chance(0) 恒 false、chance(1) 恒 true
    /// （#expect 直接包 mutating 调用会被宏重写为不可变 $0，先取结果再断言）
    @Test
    func testChanceExtremes() {
        var rng = SeededRandom(seed: 13)
        for _ in 0..<100 {
            let never = rng.chance(0.0)
            let always = rng.chance(1.0)
            #expect(!never)
            #expect(always)
        }
    }

    /// chance(0.5) 采样约一半为 true（500 次采样，容差 ±20%）
    @Test
    func testChanceHalfRoughlyHalfTrue() {
        var rng = SeededRandom(seed: 21)
        var trueCount = 0
        for _ in 0..<500 {
            if rng.chance(0.5) { trueCount += 1 }
        }
        #expect(trueCount > 150)
        #expect(trueCount < 350)
    }
}
