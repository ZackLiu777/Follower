//
//  SeededRandom.swift
//  Follower
//
//  确定性伪随机源（固定种子 LCG）— Mock 数据可复现：
//  相同种子 → 相同数据序列，测试可断言、调试可复现。
//

import Foundation

/// 确定性伪随机源 — 线性同余生成器（LCG），线程内可变状态
struct SeededRandom: Sendable {
    /// LCG 状态（UInt64 满周期 2^64）
    private var state: UInt64

    /// 用固定种子初始化（种子相同 → 序列完全相同）
    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// 下一个 [0, 1) 区间的 Double
    mutating func next() -> Double {
        // x_{n+1} = (a·x_n + c) mod 2^64（&* 溢出回绕即取模）
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    /// [lower, upper] 闭区间随机 Int（含两端）
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let width = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int((next() * Double(width)).rounded(.down))
    }

    /// [lower, upper) 区间随机 Double
    mutating func double(in range: Range<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }

    /// 从数组中随机取一个元素（数组非空）
    mutating func pick<T>(_ items: [T]) -> T {
        items[int(in: 0...(items.count - 1))]
    }

    /// 以 p 概率返回 true
    mutating func chance(_ p: Double) -> Bool {
        next() < p
    }
}
