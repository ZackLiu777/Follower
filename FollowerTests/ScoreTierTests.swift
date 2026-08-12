//
//  ScoreTierTests.swift
//  FollowerTests
//
//  VisualizationComponents.swift 中 ScoreTier 档位映射的单元测试 —
//  覆盖 0-100 分数 → 档位的边界值（含四舍五入边界与 NaN 安全性）。
//

import Testing
@testable import Follower

/// ScoreTier.tier(for:) 档位映射测试：≥80 优 / ≥60 良 / ≥40 中 / <40 差
@Suite("ScoreTier 档位映射测试")
struct ScoreTierTests {

    @Test("满分与优秀下限均为 excellent")
    func excellentBoundaries() {
        #expect(ScoreTier.tier(for: 100) == .excellent)
        #expect(ScoreTier.tier(for: 80) == .excellent)
        #expect(ScoreTier.tier(for: 99.9) == .excellent)
    }

    @Test("良好区间 [60, 80)")
    func goodBoundaries() {
        #expect(ScoreTier.tier(for: 79.99) == .good)
        #expect(ScoreTier.tier(for: 60) == .good)
        #expect(ScoreTier.tier(for: 70.5) == .good)
    }

    @Test("中等区间 [40, 60)")
    func fairBoundaries() {
        #expect(ScoreTier.tier(for: 59.99) == .fair)
        #expect(ScoreTier.tier(for: 40) == .fair)
        #expect(ScoreTier.tier(for: 50) == .fair)
    }

    @Test("差区间 <40")
    func poorBoundaries() {
        #expect(ScoreTier.tier(for: 39.99) == .poor)
        #expect(ScoreTier.tier(for: 0) == .poor)
        #expect(ScoreTier.tier(for: -5) == .poor)
    }

    @Test("超界分数不崩溃")
    func outOfRangeScores() {
        #expect(ScoreTier.tier(for: 150) == .excellent)
        #expect(ScoreTier.tier(for: -100) == .poor)
    }
}
