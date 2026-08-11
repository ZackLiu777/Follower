//
//  PredictionServiceTests.swift
//  FollowerTests
//
//  PredictionService 端到端测试（v0.15-alpha 贝叶斯模型）：
//  确定性合成数据 → 区间/概率字段有效性；恒定数据 → 预测接近 0；
//  SMA 保留行为不变。
//

import Testing
import Foundation
@testable import Follower

struct PredictionServiceTests {

    /// 合成递增数据（确定性）：每日 +5，60 点 → 预测非 nil，区间有效
    @MainActor
    @Test
    func testEndToEndPrediction() async {
        let service = PredictionService()
        let data = (0..<60).map { i in
            (Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400), Double(1_000 + i * 5))
        }
        let result = await service.predictLinear(dataPoints: data, daysAhead: 30)
        #expect(result != nil)
        guard let r = result else { return }

        #expect(r.method == "Bayesian")
        #expect(r.confidence == 0.95)
        #expect(r.predictedValue > 0)
        #expect(r.lowerBound! <= r.upperBound!)
        #expect(r.lowerBound! >= 0)  // 累计增长非负（目标截断）
        #expect(r.probabilityPositive! >= 0 && r.probabilityPositive! <= 1)
        #expect(r.growthSamples!.count == RollingForecast.sampleCount)
        // 逐日区间分位：31 点、起点 0、端点与累计一致
        let days = RollingForecast.horizonDays + 1
        #expect(r.dailyMedian!.count == days)
        #expect(r.dailyMedian![0] == 0)
        #expect(r.dailyLower![days - 1] == r.lowerBound)
        #expect(r.dailyUpper![days - 1] == r.upperBound)
        // 终点逐日中位 = 30 天累计样本中位（同分位公式）
        let sortedSamples = r.growthSamples!.sorted()
        #expect(r.dailyMedian![days - 1] == sortedSamples[sortedSamples.count / 2])
        // 预测日期 = 最后观测日 + daysAhead
        let expectedDate = Calendar.current.date(byAdding: .day, value: 30, to: data.last!.0)!
        #expect(abs(r.predictionDate.timeIntervalSince(expectedDate)) < 1)
    }

    /// 恒定粉丝数（全部 target = 0）→ 无增长信号：对数后验只有上确界
    /// （β0 → −∞ 且永不收敛），fit 返回 nil → predictLinear 返回 nil。
    /// 产品行为：无信号 → 不提供预测，调用方走"显示当前粉丝数"兜底。
    @MainActor
    @Test
    func testFlatDataPredictsNearZero() async {
        let service = PredictionService()
        let data = (0..<60).map { i in
            (Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400), 5_000.0)
        }
        let result = await service.predictLinear(dataPoints: data, daysAhead: 30)
        #expect(result == nil)
    }

    /// 数据点 < 3 → nil（保留原行为）
    @MainActor
    @Test
    func testTooFewPointsNil() async {
        let service = PredictionService()
        let data = [(Date(), 100.0), (Date(), 200.0)]
        #expect(await service.predictLinear(dataPoints: data, daysAhead: 30) == nil)
    }

    /// SMA 保留行为不变（回归防护）
    @MainActor
    @Test
    func testSMAUnchanged() async {
        let service = PredictionService()
        let data = (0..<10).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), Double(100 + i * 10))
        }
        let results = await service.predictSMA(dataPoints: data, window: 7)
        #expect(results.count == 1)
        #expect(results[0].method == "SMA7")
        #expect(results[0].predictedValue > 0)
        // SMA 不产出贝叶斯扩展字段
        #expect(results[0].lowerBound == nil)
        #expect(results[0].growthSamples == nil)
    }

    /// 乱序输入 → 预测仍成功（内部按日期排序）
    @MainActor
    @Test
    func testUnsortedInputHandled() async {
        let service = PredictionService()
        let points = (0..<60).map { i in
            (Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400), Double(1_000 + i * 5))
        }
        let reversed = points.reversed()
        let result = await service.predictLinear(dataPoints: Array(reversed), daysAhead: 30)
        #expect(result != nil)
        #expect(result!.predictedValue > 0)
    }
}
