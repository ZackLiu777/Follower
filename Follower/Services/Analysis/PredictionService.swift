//
//  PredictionService.swift
//  Follower
//
//  Gamma: 趋势预测（Premium）。简单移动平均 + 线性回归。

import Foundation

// MARK: - PredictionResult

struct PredictionResult: Sendable {
    let predictedValue: Double
    let confidence: Double        // 0-1
    let method: String            // "SMA7" / "SMA30" / "Linear"
    let predictionDate: Date
}

// MARK: - PredictionServiceProtocol

protocol PredictionServiceProtocol: Sendable {
    func predictSMA(dataPoints: [(Date, Double)], window: Int) async -> [PredictionResult]
    func predictLinear(dataPoints: [(Date, Double)], daysAhead: Int) async -> PredictionResult?
}

// MARK: - PredictionService

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

    /// 线性回归预测：基于全部数据点拟合趋势线，预测 N 天后的值
    func predictLinear(dataPoints: [(Date, Double)], daysAhead: Int) async -> PredictionResult? {
        guard dataPoints.count >= 3 else { return nil }
        let sorted = dataPoints.sorted { $0.0 < $1.0 }
        let n = Double(sorted.count)

        let indices = Array(0..<sorted.count).map(Double.init)
        let values = sorted.map(\.1)

        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        let predictedX = n + Double(daysAhead)
        let predictedValue = slope * predictedX + intercept

        let residuals = zip(indices, values).map { $1 - (slope * $0 + intercept) }
        let ssRes = residuals.map { $0 * $0 }.reduce(0, +)
        let meanY = sumY / n
        let ssTot = values.map { ($0 - meanY) * ($0 - meanY) }.reduce(0, +)
        let rSquared = ssTot > 0 ? 1 - ssRes / ssTot : 0

        let lastDate = sorted.last?.0 ?? Date()
        let predictionDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: lastDate) ?? lastDate

        return PredictionResult(predictedValue: predictedValue, confidence: max(0, min(1, rSquared)), method: "Linear", predictionDate: predictionDate)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
