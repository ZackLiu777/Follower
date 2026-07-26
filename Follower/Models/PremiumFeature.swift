//
//  PremiumFeature.swift
//  Follower
//
//  表示 Premium 功能开关与状态。Alpha 阶段保留接口。

import Foundation
import GRDB

// MARK: - PremiumFeatureKey

/// Premium 功能键枚举，覆盖预测 / 分析 / 导出 / 安全 / 同步等方向
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

    // MARK: - Phi：三大人群画像 Premium 功能
    case competitorComparison       // 竞品对比（KOL + 品牌方）
    case authenticityAssessment     // 账号真实性评估（KOL + 品牌方）
    case mediaKitExport             // 媒体包/商业价值报告导出（KOL + 品牌方）
    case campaignTracking           // 投放效果跟踪（品牌方）
    case engagementHeatmap          // 互动热力图（KOL）
    case contentScheduling          // 内容排期推荐（KOL + 中小企业）
    case commentManagement          // 评论管理（中小企业）
    case growthDecisions            // 增长决策引擎（Premium 专属 Tab）

    /// 用户可见的功能名称
    var displayName: String {
        switch self {
        case .trendPrediction: return "Trend Prediction"
        case .followerGrowthPrediction: return "Growth Prediction"
        case .activityAnalysis: return loc(L10n.Premium.activityAnalysis)
        case .retentionAnalysis: return "Retention Analysis"
        case .churnAnalysis: return "Churn Analysis"
        case .geoDistribution: return loc(L10n.Premium.geoDistribution)
        case .engagementQualityScore: return loc(L10n.Premium.engagementQuality)
        case .longTermTrendComparison: return "Long-term Trends"
        case .csvExport: return "CSV Export"
        case .excelExport: return "Excel Export"
        case .localAIAnalysis: return "Local AI Analysis"
        case .advancedEncryption: return "Advanced Encryption"
        case .multiDeviceSync: return "Multi-Device Sync"
        case .competitorComparison: return loc(L10n.Premium.competitorComparison)
        case .authenticityAssessment: return loc(L10n.Premium.authenticityAssessment)
        case .mediaKitExport: return loc(L10n.Premium.mediaKitExport)
        case .campaignTracking: return loc(L10n.Premium.campaignTracking)
        case .engagementHeatmap: return loc(L10n.Premium.engagementHeatmap)
        case .contentScheduling: return loc(L10n.Premium.contentScheduling)
        case .commentManagement: return loc(L10n.Premium.commentManagement)
        case .growthDecisions: return "Growth Decisions"
        }
    }
}

// MARK: - PremiumFeature

/// Premium 功能开关的持久化模型
struct PremiumFeature: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var key: PremiumFeatureKey
    var enabled: Bool
    var expiresAt: Date?
    var createdAt: Date

    static let databaseTableName = "premiumFeature"

    /// 插入成功后回填自增 rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Column Names

extension PremiumFeature {
    /// GRDB 列名映射
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
    /// 按功能键过滤
    func filter(key: PremiumFeatureKey) -> Self {
        filter(PremiumFeature.Columns.key == key)
    }
    /// 按启用状态过滤
    func filter(enabled: Bool) -> Self {
        filter(PremiumFeature.Columns.enabled == enabled)
    }
}
