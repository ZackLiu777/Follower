//
//  PremiumFeature.swift
//  Follower
//
//  表示 Premium 功能开关与状态。Alpha 阶段保留接口。

import Foundation
import GRDB

// MARK: - PremiumFeatureKey

enum PremiumFeatureKey: String, Codable, DatabaseValueConvertible, CaseIterable {
    case trendPrediction
    case followerGrowthPrediction
    case activityAnalysis
    case retentionAnalysis
    case churnAnalysis
    case geoDistribution
    case engagementQualityScore
    case longTermTrendComparison
    case csvExport
    case excelExport
    case localAIAnalysis
    case advancedEncryption
    case multiDeviceSync

    var displayName: String {
        switch self {
        case .trendPrediction: return "Trend Prediction"
        case .followerGrowthPrediction: return "Growth Prediction"
        case .activityAnalysis: return "Activity Analysis"
        case .retentionAnalysis: return "Retention Analysis"
        case .churnAnalysis: return "Churn Analysis"
        case .geoDistribution: return "Geo Distribution"
        case .engagementQualityScore: return "Engagement Quality"
        case .longTermTrendComparison: return "Long-term Trends"
        case .csvExport: return "CSV Export"
        case .excelExport: return "Excel Export"
        case .localAIAnalysis: return "Local AI Analysis"
        case .advancedEncryption: return "Advanced Encryption"
        case .multiDeviceSync: return "Multi-Device Sync"
        }
    }
}

// MARK: - PremiumFeature

struct PremiumFeature: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var key: PremiumFeatureKey
    var enabled: Bool
    var expiresAt: Date?
    var createdAt: Date

    static let databaseTableName = "premiumFeature"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension PremiumFeature {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let key = Column(CodingKeys.key)
        static let enabled = Column(CodingKeys.enabled)
        static let expiresAt = Column(CodingKeys.expiresAt)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - DerivableRequest

extension DerivableRequest<PremiumFeature> {
    func filter(key: PremiumFeatureKey) -> Self {
        filter(PremiumFeature.Columns.key == key)
    }
    func filter(enabled: Bool) -> Self {
        filter(PremiumFeature.Columns.enabled == enabled)
    }
}
