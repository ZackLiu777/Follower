//
//  HeatmapTierTests.swift
//  FollowerTests
//
//  HeatmapGrid.tier(for:) 5 档色阶映射的单元测试 —
//  覆盖密度 0-1 各区间的边界值（GitHub 贡献图色阶同构）。
//

import Testing
@testable import Follower

/// HeatmapGrid.tier(for:) 档位映射测试：0 灰 / 1-4 主题色递进
@Suite("HeatmapGrid 五档色阶映射测试")
struct HeatmapTierTests {

    @Test("0 密度 → 0 档（灰底，无活动）")
    func zeroIsGrey() {
        #expect(HeatmapGrid.tier(for: 0) == 0)
        #expect(HeatmapGrid.tier(for: 0.0) == 0)
    }

    @Test("(0, 0.25) → 1 档")
    func firstTier() {
        #expect(HeatmapGrid.tier(for: 0.001) == 1)
        #expect(HeatmapGrid.tier(for: 0.1) == 1)
        #expect(HeatmapGrid.tier(for: 0.2499) == 1)
    }

    @Test("[0.25, 0.5) → 2 档")
    func secondTier() {
        #expect(HeatmapGrid.tier(for: 0.25) == 2)
        #expect(HeatmapGrid.tier(for: 0.4) == 2)
        #expect(HeatmapGrid.tier(for: 0.4999) == 2)
    }

    @Test("[0.5, 0.75) → 3 档")
    func thirdTier() {
        #expect(HeatmapGrid.tier(for: 0.5) == 3)
        #expect(HeatmapGrid.tier(for: 0.6) == 3)
        #expect(HeatmapGrid.tier(for: 0.7499) == 3)
    }

    @Test("≥0.75 → 4 档（最深）")
    func topTier() {
        #expect(HeatmapGrid.tier(for: 0.75) == 4)
        #expect(HeatmapGrid.tier(for: 0.9) == 4)
        #expect(HeatmapGrid.tier(for: 1.0) == 4)
    }

    @Test("超界输入不崩溃")
    func outOfRange() {
        #expect(HeatmapGrid.tier(for: -0.5) == 0)
        #expect(HeatmapGrid.tier(for: 2.0) == 4)
    }
}
