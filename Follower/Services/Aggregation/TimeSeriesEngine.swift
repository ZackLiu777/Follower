//
//  TimeSeriesEngine.swift
//  Follower
//
//  Sigma: 统一时间桶聚合引擎。消除 year window 重复 label bug。
//

import Foundation

/// 时间桶粒度枚举：hour / day / week / month / year
enum TimeBucket {
    case hour, day, week, month, year
}

/// 统一时间桶聚合引擎：将 Metric 数组按指定桶粒度聚合为 TrendDataPoint 序列
final class TimeSeriesEngine {
    static let calendar: Calendar = Calendar.current

    /// 将日期归一化到 bucket 起始边界
    static func bucketStart(_ date: Date, by bucket: TimeBucket) -> Date {
        switch bucket {
        case .hour:  calendar.dateInterval(of: .hour, for: date)!.start
        case .day:   calendar.startOfDay(for: date)
        case .week:  calendar.dateInterval(of: .weekOfYear, for: date)!.start
        case .month: calendar.dateInterval(of: .month, for: date)!.start
        case .year:  calendar.dateInterval(of: .year, for: date)!.start
        }
    }

    /// 将 Metric 数组按时间桶聚合为 TrendDataPoint
    /// 每个 bucket 内取均值，保证 1 bucket = 1 data point（强约束）
    static func aggregate(_ metrics: [Metric], bucket: TimeBucket) -> [TrendDataPoint] {
        let grouped = Dictionary(grouping: metrics) { bucketStart($0.observedAt, by: bucket) }
        return grouped.map { (key, values) in
            TrendDataPoint(date: key, value: values.map(\.value).reduce(0, +) / Double(values.count))
        }
        .sorted { $0.date < $1.date }
    }
}
