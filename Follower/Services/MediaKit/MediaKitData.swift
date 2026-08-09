//
//  MediaKitData.swift
//  Follower
//
//  媒体包（Media Kit）数据模型 — 数据收集层的产物，供 PDF 排版消费。
//  排版只读此模型，不触碰 Repository，保证「收集 → 渲染」解耦。
//

import Foundation

/// 核心指标行：名称 / 数值 / 7 天环比（nil = 无历史数据）
struct MediaKitMetricRow {
    let label: String
    let value: Double
    let formattedValue: String
    let delta: Double?      // 环比百分比（7 天）
    let deltaLabel: String  // "+12.3%" / "—"
}

/// 粉丝增长趋势点（周粒度）
struct MediaKitGrowthPoint {
    let date: Date
    let followers: Int
}

/// 帖子类型分布（IMAGE / VIDEO / CAROUSEL_ALBUM）
struct MediaKitPostTypeCount {
    let type: String
    let count: Int
}

/// 媒体包完整数据 — MediaKitDataProvider 从 Repository 收集
struct MediaKitData {
    let account: Account
    let snapshot: Snapshot?
    let metricRows: [MediaKitMetricRow]     // 核心指标页（6 行）
    let weeklyGrowth: [MediaKitGrowthPoint] // 增长趋势页（12 周）
    let topPosts: [MediaPost]               // 内容表现页（Top 5）
    let postTypeCounts: [MediaKitPostTypeCount]
    let avgLikesSeries: [Double]            // 互动质量页（30 天均赞）
    let avgCommentsSeries: [Double]         // 互动质量页（30 天均评）
    let engagementSeries: [Double]          // 互动质量页（30 天互动率 %）
    /// 趋势统计序列（完整模板用）：指标 → 30 天日窗口（粉丝用 weeklyGrowth 的周窗口）
    let trendSeries: [MetricType: [Double]]
    /// 周窗口竖柱状图序列（趋势柱状页用）：6 指标 × 最近 7 周
    let weeklySeries: [MetricType: [Double]]
    /// 增长决策建议（决策引擎生成，最多 3 张；无数据时为空）
    let actionCards: [ActionCard]
    let generatedAt: Date
}

// MARK: - 模板

/// 媒体包模板：决定页面组合与封面视觉
enum MediaKitTemplate: String, CaseIterable, Identifiable {
    case professional   // 专业：完整内容 + 浅色专业风（默认）
    case creative       // 创意：完整内容 + 品牌渐变封面
    case minimal        // 极简：仅封面 + 核心指标 + 结语

    var id: String { rawValue }

    /// 模板显示名（L10n）
    var displayName: String {
        switch self {
        case .professional: return loc(L10n.Premium.templateProfessional)
        case .creative: return loc(L10n.Premium.templateCreative)
        case .minimal: return loc(L10n.Premium.templateMinimal)
        }
    }

    /// 模板说明（L10n）
    var detailDescription: String {
        switch self {
        case .professional: return loc(L10n.MediaKit.templateProfessionalDesc)
        case .creative: return loc(L10n.MediaKit.templateCreativeDesc)
        case .minimal: return loc(L10n.MediaKit.templateMinimalDesc)
        }
    }
}
