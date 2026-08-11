//
//  FeatureEngineTests.swift
//  FollowerTests
//
//  特征工程测试：
//  手算特征值、负增长截断、同日期去重、乱序排序、标准化往返、常数特征、数据量门槛。
//

import Testing
import Foundation
@testable import Follower

struct FeatureEngineTests {

    // MARK: - 测试数据

    /// 10 个升序观测点（日间隔 1），followers 缓慢递增
    private func makePoints() -> [GrowthPoint] {
        let followers = [100, 102, 103, 105, 106, 108, 109, 111, 113, 115]
        return followers.enumerated().map {
            GrowthPoint(date: Date(timeIntervalSince1970: Double($0.offset)), followers: $0.element)
        }
    }

    // MARK: - 特征手算

    /// t=7 与 t=8 两行（n=10 → t ∈ 7...8）逐维手算对比
    @Test
    func testBuildRowsHandComputed() {
        let rows = FeatureEngine.buildRows(points: makePoints())
        #expect(rows.count == 2)

        // t=7：f[7]=111, f[0]=100
        let r0 = rows[0]
        #expect(abs(r0.features[0] - log(111)) < 1e-9)          // log_followers
        #expect(abs(r0.features[1] - 11.0 / 7.0) < 1e-9)        // momentum_7d
        #expect(abs(r0.features[2] - 1.5) < 1e-9)               // accel：slope([102,103,105,106,108,109,111])
        #expect(abs(r0.features[3] - 2) < 1e-9)                 // lag_1d
        #expect(r0.target == 2)                                  // f[8]−f[7]

        // t=8：f[8]=113, f[1]=102
        let r1 = rows[1]
        #expect(abs(r1.features[0] - log(113)) < 1e-9)
        #expect(abs(r1.features[1] - 11.0 / 7.0) < 1e-9)
        #expect(abs(r1.features[2] - 315.0 / 196.0) < 1e-9)     // slope([103,105,106,108,109,111,113])
        #expect(abs(r1.features[3] - 2) < 1e-9)
        #expect(r1.target == 2)
    }

    /// 负增长 → 目标截断为 0
    @Test
    func testTargetTruncation() {
        var followers = [Int](repeating: 100, count: 9)
        followers.append(90)  // 最后一点掉粉
        let points = followers.enumerated().map {
            GrowthPoint(date: Date(timeIntervalSince1970: Double($0.offset)), followers: $0.element)
        }
        let rows = FeatureEngine.buildRows(points: points)
        #expect(rows.count == 2)
        #expect(rows[0].target == 0)  // f[8]−f[7] = 0
        #expect(rows[1].target == 0)  // f[9]−f[8] = −10 → 0
    }

    // MARK: - 去重与排序

    /// 同日期多条 → 保留最后一次观测（后到覆盖）；乱序输入 → 按日期升序
    @Test
    func testDeduplicateAndSort() {
        let d0 = Date(timeIntervalSince1970: 0)
        let d1 = Date(timeIntervalSince1970: 86_400)
        let d2 = Date(timeIntervalSince1970: 172_800)
        let points = [
            GrowthPoint(date: d1, followers: 5),   // 将被覆盖
            GrowthPoint(date: d0, followers: 3),   // 将被覆盖
            GrowthPoint(date: d1, followers: 6),
            GrowthPoint(date: d0, followers: 4),
            GrowthPoint(date: d2, followers: 7),
        ]
        let rows = FeatureEngine.buildRows(points: points)
        // 9 点 → 无行，但通过 target 检查日期排序与覆盖：用 10 点补足
        _ = rows
        let padded = points + [
            GrowthPoint(date: Date(timeIntervalSince1970: 259_200), followers: 8),
            GrowthPoint(date: Date(timeIntervalSince1970: 345_600), followers: 9),
            GrowthPoint(date: Date(timeIntervalSince1970: 432_000), followers: 10),
            GrowthPoint(date: Date(timeIntervalSince1970: 518_400), followers: 11),
            GrowthPoint(date: Date(timeIntervalSince1970: 604_800), followers: 12),
        ]
        let full = FeatureEngine.buildRows(points: padded)
        #expect(full.count == 3)
        // t=7 对应去重后的第 7 个点：日期 d1 的保留值 6（后到覆盖）
        let t7Features = full[0].features
        let f = [4.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        #expect(abs(t7Features[0] - log(f[7])) < 1e-9)
        #expect(abs(t7Features[1] - (f[7] - f[0]) / 7) < 1e-9)
        #expect(abs(t7Features[3] - (f[7] - f[6])) < 1e-9)
    }

    // MARK: - 标准化

    /// 标准化 → 反标准化往返 ≈ 原特征
    @Test
    func testStandardizeRoundTrip() {
        let rows = FeatureEngine.buildRows(points: makePoints())
        let (scaled, stats) = FeatureEngine.standardize(rows: rows)
        #expect(stats.means.count == FeatureEngine.featureCount)
        #expect(stats.stds.count == FeatureEngine.featureCount)

        for (original, s) in zip(rows, scaled) {
            let restored = FeatureEngine.unstandardized(features: s.features, stats: stats)
            for d in 0..<FeatureEngine.featureCount {
                #expect(abs(restored[d] - original.features[d]) < 1e-10)
            }
            #expect(s.target == original.target)  // 目标不标准化
        }
        // 单行标准化与批量同公式
        let single = FeatureEngine.standardize(features: rows[0].features, stats: stats)
        for d in 0..<FeatureEngine.featureCount {
            #expect(abs(single[d] - scaled[0].features[d]) < 1e-12)
        }
    }

    /// 常数特征（std < 1e-12）→ 不缩放，标准化后仍为 0
    @Test
    func testConstantFeatureNotScaled() {
        let rows = [
            FeatureRow(features: [0, 0, 0, 0], target: 1),
            FeatureRow(features: [0, 0, 0, 0], target: 2),
            FeatureRow(features: [0, 0, 0, 0], target: 3),
        ]
        let (scaled, stats) = FeatureEngine.standardize(rows: rows)
        for s in stats.stds {
            #expect(s == 1)
        }
        for row in scaled {
            for v in row.features {
                #expect(v == 0)
            }
        }
    }

    /// 反标准化手算：stats 已知 → x' = x·std + mean
    @Test
    func testUnstandardizedHandComputed() {
        let stats = FeatureStats(means: [10, 100, 5, -3], stds: [2, 50, 0.5, 1])
        let restored = FeatureEngine.unstandardized(features: [0, 1, -1, 6], stats: stats)
        #expect(restored.count == 4)
        #expect(abs(restored[0] - 10) < 1e-12)     // 0·2+10
        #expect(abs(restored[1] - 150) < 1e-12)    // 1·50+100
        #expect(abs(restored[2] - 4.5) < 1e-12)    // −1·0.5+5
        #expect(abs(restored[3] - 3) < 1e-12)      // 6·1−3
    }

    /// 反标准化与 standardize 互逆：任意特征向量往返
    @Test
    func testUnstandardizedIsInverseOfStandardize() {
        let stats = FeatureStats(means: [7.5, -2.0, 0.25, 42], stds: [3.0, 0.5, 1.5, 10])
        let originals: [[Double]] = [
            [1, 2, 3, 4],
            [7.5, -2.0, 0.25, 42],
            [-100, 100, 0, 0.01],
        ]
        for original in originals {
            let scaled = FeatureEngine.standardize(features: original, stats: stats)
            let restored = FeatureEngine.unstandardized(features: scaled, stats: stats)
            for d in 0..<original.count {
                #expect(abs(restored[d] - original[d]) < 1e-10)
            }
        }
    }

    /// 单行标准化手算：stats 已知 → x' = (x − mean)/std
    @Test
    func testStandardizeSingleHandComputed() {
        let stats = FeatureStats(means: [0, 10, -5, 100], stds: [1, 2, 5, 0.5])
        let scaled = FeatureEngine.standardize(features: [0, 0, 0, 0], stats: stats)
        #expect(abs(scaled[0] - 0) < 1e-12)      // (0−0)/1
        #expect(abs(scaled[1] + 5) < 1e-12)      // (0−10)/2 = −5
        #expect(abs(scaled[2] - 1) < 1e-12)      // (0+5)/5 = 1
        #expect(abs(scaled[3] + 200) < 1e-12)    // (0−100)/0.5 = −200
    }

    // MARK: - 数据量门槛

    /// 少于 9 点（t 需 ≥7 且 target 需 t+1）→ 无行
    @Test
    func testMinimumPoints() {
        let points = makePoints()
        #expect(FeatureEngine.buildRows(points: Array(points.prefix(8))).isEmpty)
        #expect(FeatureEngine.buildRows(points: Array(points.prefix(9))).count == 1)
    }

    /// 空输入 → 空输出
    @Test
    func testEmptyInput() {
        #expect(FeatureEngine.buildRows(points: []).isEmpty)
        let (scaled, stats) = FeatureEngine.standardize(rows: [])
        #expect(scaled.isEmpty && stats.means.isEmpty && stats.stds.isEmpty)
    }

    // MARK: - leastSquaresSlope 直接测试（internal）

    /// 精确线性序列 → 斜率 = 步长（等差序列最小二乘斜率解析 = 公差）
    @Test
    func testLeastSquaresSlopeLinear() {
        // [0,1,2,3,4] → 斜率 1；[10,14,18,22] → 斜率 4；[0,-2,-4] → 斜率 −2
        #expect(abs(FeatureEngine.leastSquaresSlope([0, 1, 2, 3, 4]) - 1.0) < 1e-12)
        #expect(abs(FeatureEngine.leastSquaresSlope([10, 14, 18, 22]) - 4.0) < 1e-12)
        #expect(abs(FeatureEngine.leastSquaresSlope([0, -2, -4]) + 2.0) < 1e-12)
    }

    /// 常数序列 → 斜率 0
    @Test
    func testLeastSquaresSlopeConstant() {
        #expect(abs(FeatureEngine.leastSquaresSlope([5, 5, 5, 5, 5])) < 1e-12)
        #expect(abs(FeatureEngine.leastSquaresSlope([-3])) < 1e-12)          // 单点
        #expect(abs(FeatureEngine.leastSquaresSlope([7, 7])) < 1e-12)        // 两点相等
    }

    /// 手算案例：x=[0,1,2,3], y=[1,3,6,10] → 最小二乘斜率
    @Test
    func testLeastSquaresSlopeHandComputed() {
        // Σx=6, Σy=20, Σxy=0+3+12+30=45, Σx²=14, n=4
        // slope = (4·45 − 6·20)/(4·14 − 36) = (180−120)/20 = 3
        let slope = FeatureEngine.leastSquaresSlope([1, 3, 6, 10])
        #expect(abs(slope - 3.0) < 1e-12)
    }

    // MARK: - deduplicate 直接测试（internal）

    /// 同日期多条 → 保留最后一次；输出保持原顺序
    @Test
    func testDeduplicateKeepsLastAndOrder() {
        let d0 = Date(timeIntervalSince1970: 0)
        let d1 = Date(timeIntervalSince1970: 86_400)
        let input = [
            GrowthPoint(date: d0, followers: 1),
            GrowthPoint(date: d1, followers: 2),
            GrowthPoint(date: d0, followers: 3),   // 覆盖 d0
            GrowthPoint(date: d1, followers: 4),   // 覆盖 d1
            GrowthPoint(date: d0, followers: 5),   // 再覆盖 d0
        ]
        let out = FeatureEngine.deduplicate(input)
        #expect(out.count == 2)
        #expect(out[0].date == d0 && out[0].followers == 5)
        #expect(out[1].date == d1 && out[1].followers == 4)
    }

    /// 全同日期 → 只剩一个；无重复 → 原样返回
    @Test
    func testDeduplicateExtremes() {
        let d = Date(timeIntervalSince1970: 1000)
        let allSame = (0..<10).map { GrowthPoint(date: d, followers: $0) }
        let collapsed = FeatureEngine.deduplicate(allSame)
        #expect(collapsed.count == 1)
        #expect(collapsed[0].followers == 9)  // 最后一次观测

        let unique = (0..<4).map { GrowthPoint(date: Date(timeIntervalSince1970: Double($0)), followers: $0) }
        let kept = FeatureEngine.deduplicate(unique)
        #expect(kept.count == 4)
        #expect(kept[0].followers == 0 && kept[3].followers == 3)
    }
}
