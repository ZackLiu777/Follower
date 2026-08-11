//
//  PredictionService.swift
//  Follower
//
//  Gamma: 趋势预测（Premium）。简单移动平均 + 贝叶斯负二项回归。
//  v0.15-alpha: predictLinear 由索引线性回归切换为贝叶斯负二项回归
//  （Laplace 近似 + 滚动采样），输出 95% 预测可信区间与增长概率。
//  详见 docs/specs/prediction-bayesian-model.md。

import Foundation

// MARK: - PredictionResult

/// 预测结果：预测值 / 置信度 / 方法名 / 预测日期
struct PredictionResult: Sendable {
    let predictedValue: Double
    let confidence: Double        // 0-1
    let method: String            // "SMA7" / "SMA30" / "Bayesian"
    let predictionDate: Date
    // 贝叶斯预测扩展字段（SMA 不产出，恒 nil）
    let lowerBound: Double?           // 95% ETI 下界（预测窗内累计增长）
    let upperBound: Double?           // 95% ETI 上界
    let probabilityPositive: Double?  // P(增长 > 0)
    let growthSamples: [Double]?      // 累计增长采样（详情页分布图备用）
    let dailyLower: [Double]?         // 逐日累计增长 2.5% 分位（31 点，含起点 0）
    let dailyQ10: [Double]?           // 逐日累计增长 10% 分位（80% 带）
    let dailyQ25: [Double]?           // 逐日累计增长 25% 分位（50% 带）
    let dailyMedian: [Double]?        // 逐日累计增长中位数
    let dailyQ75: [Double]?           // 逐日累计增长 75% 分位（50% 带上界）
    let dailyQ90: [Double]?           // 逐日累计增长 90% 分位（80% 带上界）
    let dailyUpper: [Double]?         // 逐日累计增长 97.5% 分位（95% 带上界）

    init(
        predictedValue: Double,
        confidence: Double,
        method: String,
        predictionDate: Date,
        lowerBound: Double? = nil,
        upperBound: Double? = nil,
        probabilityPositive: Double? = nil,
        growthSamples: [Double]? = nil,
        dailyLower: [Double]? = nil,
        dailyQ10: [Double]? = nil,
        dailyQ25: [Double]? = nil,
        dailyMedian: [Double]? = nil,
        dailyQ75: [Double]? = nil,
        dailyQ90: [Double]? = nil,
        dailyUpper: [Double]? = nil
    ) {
        self.predictedValue = predictedValue
        self.confidence = confidence
        self.method = method
        self.predictionDate = predictionDate
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.probabilityPositive = probabilityPositive
        self.growthSamples = growthSamples
        self.dailyLower = dailyLower
        self.dailyQ10 = dailyQ10
        self.dailyQ25 = dailyQ25
        self.dailyMedian = dailyMedian
        self.dailyQ75 = dailyQ75
        self.dailyQ90 = dailyQ90
        self.dailyUpper = dailyUpper
    }
}

// MARK: - PredictionServiceProtocol

/// 趋势预测服务协议（Premium）
protocol PredictionServiceProtocol: Sendable {
    /// 简单移动平均预测
    func predictSMA(dataPoints: [(Date, Double)], window: Int) async -> [PredictionResult]
    /// 贝叶斯负二项回归预测 N 天后的累计增长
    func predictLinear(dataPoints: [(Date, Double)], daysAhead: Int) async -> PredictionResult?
}

// MARK: - PredictionService

/// 预测服务实现：SMA 简单移动平均 + 贝叶斯负二项回归
final class PredictionService: PredictionServiceProtocol {

    /// 简单移动平均预测：取最近 `window` 个数据点的均值作为下一个预测值
    func predictSMA(dataPoints: [(Date, Double)], window: Int) async -> [PredictionResult] {
        guard dataPoints.count >= window else { return [] }
        let sorted = dataPoints.sorted { $0.0 < $1.0 }
        let recent = sorted.suffix(window)
        let avg = recent.map(\.1).reduce(0, +) / Double(window)

        let stdDev = standardDeviation(recent.map(\.1))
        let confidence = max(0, min(1, 1.0 - (stdDev / (avg + 1))))

        let lastDate = sorted.last?.0 ?? Date()
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate

        return [PredictionResult(predictedValue: avg, confidence: confidence, method: "SMA\(window)", predictionDate: nextDate)]
    }

    /// 贝叶斯负二项回归预测：Laplace 后验 + 滚动采样，输出未来 `daysAhead`
    /// 天累计增长的点估计与 95% 预测可信区间（ETI）。
    /// 冷启动（特征行 < 30）或拟合失败 → nil（调用方保持现有兜底逻辑）。
    /// 注：预测窗由 RollingForecast.horizonDays 固定（30 天），与调用方约定一致。
    func predictLinear(dataPoints: [(Date, Double)], daysAhead: Int) async -> PredictionResult? {
        guard dataPoints.count >= 3 else { return nil }
        let sorted = dataPoints.sorted { $0.0 < $1.0 }
        let points = sorted.map { GrowthPoint(date: $0.0, followers: Int($0.1)) }

        // 特征构建 + 标准化 + Laplace 拟合（任一环节数据不足 → nil）
        let rows = FeatureEngine.buildRows(points: points)
        guard rows.count >= LaplaceApproximation.minRows else { return nil }
        let (scaled, stats) = FeatureEngine.standardize(rows: rows)
        guard let posterior = LaplaceApproximation.fit(rows: scaled) else { return nil }

        // 滚动预测：最近 8 点窗口，500 路径 × 30 天
        let window = Array(points.suffix(RollingForecast.windowSize))
        var rng = SystemRandomNumberGenerator()
        guard let forecast = RollingForecast.forecast(
            posterior: posterior, window: window, stats: stats, using: &rng
        ) else { return nil }

        let lastDate = sorted.last?.0 ?? Date()
        let predictionDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: lastDate) ?? lastDate

        return PredictionResult(
            predictedValue: forecast.mean,
            confidence: 0.95,
            method: "Bayesian",
            predictionDate: predictionDate,
            lowerBound: forecast.lowerBound,
            upperBound: forecast.upperBound,
            probabilityPositive: forecast.probabilityPositive,
            growthSamples: forecast.samples,
            dailyLower: forecast.dailyLower,
            dailyQ10: forecast.dailyQ10,
            dailyQ25: forecast.dailyQ25,
            dailyMedian: forecast.dailyMedian,
            dailyQ75: forecast.dailyQ75,
            dailyQ90: forecast.dailyQ90,
            dailyUpper: forecast.dailyUpper
        )
    }

    /// 计算标准差，用于评估 SMA 预测的置信度
    private func standardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
