//
//  Metric.swift
//  Follower
//
//  表示派生分析指标。由 Aggregation Service 在后台计算生成。

import Foundation
import GRDB

// MARK: - MetricType

/// 指标类型：增长 / 互动趋势 / 均赞 / 均评 / 均分享 / 触达 / 浏览 及 Premium 预留
enum MetricType: String, Codable, DatabaseValueConvertible {
    case followerGrowth
    case engagementTrend
    case averageLikes
    case averageComments
    case averageShares
    case reachEstimate
    case profileViews
    // Gamma: Premium analysis metrics
    case engagementQualityScore
    case longTermTrendComparison
    case activityAnalysis
    case retentionAnalysis
    case churnAnalysis
    case followerGrowthPrediction
    case trendPrediction
    case geoDistribution
    case localAIAnalysis
}

// MARK: - TimeWindow

/// 聚合时间窗口：日 / 周 / 月 / 年
enum TimeWindow: String, Codable, DatabaseValueConvertible {
    case day
    case week
    case month
    case year
}

// MARK: - Metric

/// 派生分析指标的持久化模型
struct Metric: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var accountId: Int64
    var metricType: MetricType
    var value: Double
    var window: TimeWindow
    var observedAt: Date
    var createdAt: Date

    static let databaseTableName = "metric"

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension Metric {
    /// GRDB 列名映射
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

// MARK: - MetricType Localization

extension MetricType {
    /// 返回当前语言的指标名称（粉丝/互动/点赞/评论/分享/浏览/触达）
    var localizedName: String {
        switch self {
        case .followerGrowth:  return loc(L10n.Trends.followers)
        case .engagementTrend: return loc(L10n.Trends.engagement)
        case .averageLikes:    return loc(L10n.Trends.likes)
        case .averageComments: return loc(L10n.Trends.comments)
        case .averageShares:   return loc(L10n.Trends.shares)
        case .profileViews:    return loc(L10n.Trends.views)
        case .reachEstimate:   return loc(L10n.Trends.reach)
        default:               return "\(self)"
        }
    }
}

// MARK: - TimeWindow Extensions

extension TimeWindow: CaseIterable {
    /// 四窗口枚举顺序：日 → 周 → 月 → 年
    public static var allCases: [TimeWindow] { [.day, .week, .month, .year] }
    /// 返回当前语言的窗口名称（日/周/月/年）
    var localizedName: String {
        switch self {
        case .day:   return loc(L10n.Trends.daily)
        case .week:  return loc(L10n.Trends.weekly)
        case .month: return loc(L10n.Trends.monthly)
        case .year:  return loc(L10n.Trends.yearly)
        }
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<Metric> {
    /// 按账号 ID 过滤
    func filter(accountId: Int64) -> Self {
        filter(Metric.Columns.accountId == accountId)
    }
    /// 按指标类型过滤
    func filter(metricType: MetricType) -> Self {
        filter(Metric.Columns.metricType == metricType)
    }
    /// 按时间窗口过滤
    func filter(window: TimeWindow) -> Self {
        filter(Metric.Columns.window == window)
    }
    /// 按观测时间排序，默认降序（最新在前）
    func orderedByObservedAt(ascending: Bool = false) -> Self {
        ascending
            ? order(Metric.Columns.observedAt.asc)
            : order(Metric.Columns.observedAt.desc)
    }
}
