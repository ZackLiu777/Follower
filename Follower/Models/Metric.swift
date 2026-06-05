//
//  Metric.swift
//  Follower
//
//  表示派生分析指标。由 Aggregation Service 在后台计算生成。

import Foundation
import GRDB

// MARK: - MetricType

enum MetricType: String, Codable, DatabaseValueConvertible {
    case followerGrowth
    case engagementTrend
    case averageLikes
    case averageComments
    case averageShares
    case reachEstimate
    case profileViews
}

// MARK: - TimeWindow

enum TimeWindow: String, Codable, DatabaseValueConvertible {
    case day
    case week
    case month
}

// MARK: - Metric

struct Metric: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var accountId: Int64
    var metricType: MetricType
    var value: Double
    var window: TimeWindow
    var observedAt: Date
    var createdAt: Date

    static let databaseTableName = "metric"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Metric {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let accountId = Column(CodingKeys.accountId)
        static let metricType = Column(CodingKeys.metricType)
        static let value = Column(CodingKeys.value)
        static let window = Column(CodingKeys.window)
        static let observedAt = Column(CodingKeys.observedAt)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Metric> {
    func filter(accountId: Int64) -> Self {
        filter(Metric.Columns.accountId == accountId)
    }
    func filter(metricType: MetricType) -> Self {
        filter(Metric.Columns.metricType == metricType)
    }
    func filter(window: TimeWindow) -> Self {
        filter(Metric.Columns.window == window)
    }
    func orderedByObservedAt(ascending: Bool = false) -> Self {
        ascending
            ? order(Metric.Columns.observedAt.asc)
            : order(Metric.Columns.observedAt.desc)
    }
}
