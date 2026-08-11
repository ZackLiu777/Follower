//
//  MockDataForecastTests.swift
//  FollowerTests
//
//  v0.15.1 回归：用真实 MockInstagramAPIClient 数据（用户场景：90 天窗口）
//  验证 predictLinear 非 nil —— 冷启动提示 currently 90 days 但预测仍为 nil
//  指向模型层在真实数据上失败（fit 数值 / 协方差正定性）。
//

import Testing
import Foundation
@testable import Follower

struct MockDataForecastTests {

    /// 用户场景复现：mock 账号 sync 后 90 天窗口快照 → predictLinear 必须非 nil
    @MainActor
    @Test
    func testMock90DaysProducesForecast() async {
        let client = MockInstagramAPIClient(seed: MockInstagramAPIClient.defaultSeed)
        let insights = try! await client.fetchInsights(
            accessToken: MockInstagramAPIClient.sentinelToken,
            metrics: ["follower_count"],
            period: "day"
        )
        guard let followerInsight = insights.first(where: { $0.name == "follower_count" }),
              let values = followerInsight.values else {
            Issue.record("mock 无 follower_count insight")
            return
        }

        // 与 DashboardViewModel 相同的解析路径：ISO8601 → (Date, Double)
        let iso = ISO8601DateFormatter()
        let points = values.compactMap { dp -> (Date, Double)? in
            guard let s = dp.endTime, let v = dp.value, let d = iso.date(from: s) else { return nil }
            return (d, v)
        }
        #expect(points.count == 730, "mock 应生成 730 天日频数据")

        // 用户场景：90 天窗口（DashboardViewModel.loadPremiumInsights 同窗口）
        let recent = Array(points.suffix(90))
        let service = PredictionService()
        let result = await service.predictLinear(dataPoints: recent, daysAhead: 30)

        #expect(result != nil, "mock 90 天数据必须产生预测——fit/forecast 在真实数据上返回 nil")
    }

    /// 分步定位：Laplace fit 是否成功（隔离 forecast 环节）
    @MainActor
    @Test
    func testLaplaceFitOnMockData() async {
        let client = MockInstagramAPIClient(seed: MockInstagramAPIClient.defaultSeed)
        let insights = try! await client.fetchInsights(
            accessToken: MockInstagramAPIClient.sentinelToken,
            metrics: ["follower_count"],
            period: "day"
        )
        let values = insights.first { $0.name == "follower_count" }?.values ?? []
        let iso = ISO8601DateFormatter()
        let points = values.compactMap { dp -> (Date, Double)? in
            guard let s = dp.endTime, let v = dp.value, let d = iso.date(from: s) else { return nil }
            return (d, v)
        }
        let recent = Array(points.suffix(90))
        let rows = FeatureEngine.buildRows(points: recent.map { GrowthPoint(date: $0.0, followers: Int($0.1)) })
        #expect(rows.count >= LaplaceApproximation.minRows, "90 天窗口应产出 ≥ 30 特征行（buildRows 非 nil 语义：不足返回空数组）")

        let (scaled, stats) = FeatureEngine.standardize(rows: rows)
        let posterior = LaplaceApproximation.fit(rows: scaled)
        #expect(posterior != nil, "Laplace fit 在 mock 数据上返回 nil")

        // 协方差必须正定（Cholesky 分解成功）— forecast 的前置条件
        if let posterior {
            let cholesky = posterior.covariance.choleskyLower()
            #expect(cholesky != nil, "协方差非正定 → RollingForecast 返回 nil（根因）")
            // 对角线必须 > 0（数值正定性检查）
            let n = posterior.covariance.rows
            let diagPositive = (0..<n).allSatisfy { posterior.covariance[$0, $0] > 0 }
            #expect(diagPositive, "协方差对角存在 ≤ 0")
            _ = stats
        }
    }
}
