//
//  GrowthFeatures.swift
//  Follower
//
//  特征提取结果的数据模型 — 定义内容表现、粉丝健康、发帖时间画像、
//  内容疲劳检测等所有可评分维度的聚合结构。

import Foundation

// MARK: - ContentType

/// 内容类型：Reel / 轮播图 / 单图
enum ContentType: String, Sendable, CaseIterable {
    /// 短视频 Reel — Instagram 当前最高 ROI 格式
    case reel
    /// 多图轮播 Carousel
    case carousel
    /// 单张图片 Photo
    case photo
}

// MARK: - ContentStats

/// 单种内容类型的表现统计数据
struct ContentStats: Sendable {
    /// 内容类型
    let type: ContentType
    /// 平均互动率（likes + comments + shares）/ impressions
    let avgEngagement: Double
    /// 历史帖子总数
    let totalPosts: Int
    /// 最近 7 天发帖数
    let recentPosts: Int
    /// 互动增长趋势（正数=上升，负数=下降）
    let growthRate: Double
}

// MARK: - FollowerHealth

/// 粉丝健康度快照
struct FollowerHealth: Sendable {
    /// 活跃粉丝数（近 30 天有互动）
    let activeFollowers: Int
    /// 不活跃粉丝数
    let inactiveFollowers: Int
    /// 粉丝总数
    let totalFollowers: Int
    /// 活跃粉丝占比（计算属性）
    var activeRatio: Double {
        totalFollowers > 0 ? Double(activeFollowers) / Double(totalFollowers) : 0
    }
    /// 近 7 天粉丝增长数
    let followerGrowth7d: Double
    /// 近 30 天粉丝增长数
    let followerGrowth30d: Double
    /// 近 7 天浏览增量（快照 totalViews 差值，按观测跨度换算）
    let viewsGrowth7d: Double
}

// MARK: - FatigueIndex

/// 内容疲劳检测指标 — 用于识别过度发布的内容类型
struct FatigueIndex: Sendable {
    /// 检测的内容类型
    let contentType: ContentType
    /// 最近 7 天发帖数
    let posts7d: Int
    /// 互动趋势（正=改善，负=恶化）
    let engagementTrend: Double
    /// 是否疲劳（由 FeatureExtractor 根据动态阈值判定，无硬编码常量）
    let isFatigued: Bool
    /// 疲劳惩罚系数（0.0 ~ 0.5，由 FeatureExtractor 动态计算）
    let penalty: Double
}

// MARK: - ImpactSummary

/// 量化收益摘要 — 由 ImpactEstimator 从真实数据计算，
/// 供 CardGenerator 为每条建议生成"预计 +N 粉丝 / +M 浏览"数字。
/// 所有收益均为基于转化率的估算（API 无单帖粉丝归因字段）。
/// v1.2：移除时段字段（时间类建议已从产品中移除，时段推断存在小样本误导风险）。
struct ImpactSummary: Sendable {
    /// 账号级转化率（浏览/点赞 → 粉丝）
    let rates: ImpactEstimator.ConversionRates
    /// 每种内容类型每发一帖的预计粉丝收益
    let perPostFollowerGain: [ContentType: Double]
    /// 每种内容类型每发一帖的预计浏览收益
    let perPostViewsGain: [ContentType: Double]
}

// MARK: - AccountPhase

/// 账号增长阶段 — 由快照涨粉信号综合判定，驱动精选机会分动态加权。
/// 不同阶段 → 不同模板加权 → 决策页精选组合随账号状态变化。
enum AccountPhase: String, Sendable {
    /// 增长期 — 本周涨粉正常
    case growing
    /// 下滑期 — 本周净负增长或明显低于 30 日速率
    case declining
    /// 停滞期 — 涨粉趋近 0
    case stagnant
    /// 爆发期 — 本周涨粉 ≥ 30 日周均 2 倍
    case viral
}

// MARK: - TrendSignal

/// 周序列趋势信号 — 前半段 vs 后半段平均，方向分类
struct TrendSignal: Sendable {
    /// 前半段平均
    let firstHalf: Double
    /// 后半段平均
    let lastHalf: Double

    /// 变化率 (last - first) / first（first 为 0 时返回 0）
    var changeRatio: Double {
        firstHalf > 0 ? (lastHalf - firstHalf) / firstHalf : 0
    }

    /// 方向分类（阈值 ±10%）
    var direction: TrendDirection {
        if changeRatio > 0.1 { return .up }
        if changeRatio < -0.1 { return .down }
        return .flat
    }
}

/// 趋势方向
enum TrendDirection: String, Sendable {
    case up, down, flat
}

// MARK: - WeekOverWeek

/// 本周 vs 上周对比（真实快照 / 帖子 / 指标计算）
struct WeekOverWeek: Sendable {
    /// 本周发帖数
    let postsThisWeek: Int
    /// 上周发帖数
    let postsLastWeek: Int
    /// 本周涨粉（快照差值）
    let followersThisWeek: Double
    /// 上周涨粉
    let followersLastWeek: Double
    /// 本周浏览增量
    let viewsThisWeek: Double
    /// 上周浏览增量
    let viewsLastWeek: Double
    /// 本周互动总量（点赞+评论 日增量）
    let engagementThisWeek: Double
    /// 上周互动总量
    let engagementLastWeek: Double
}

// MARK: - DecisionContext

/// 决策上下文 — 触发 40+ 模板所需的全部特征。
/// 由 FeatureExtractor 从真实数据计算（零硬编码触发阈值集中在引擎层）。
struct DecisionContext: Sendable {
    /// 周对比（涨粉 / 浏览 / 互动 / 发帖）
    let weekOverWeek: WeekOverWeek
    /// 触达趋势（reachEstimate 周序列）
    let reachTrend: TrendSignal
    /// 主页浏览趋势（profileViews 周序列）
    let profileViewsTrend: TrendSignal
    /// 平均点赞趋势（averageLikes 周序列）
    let likesTrend: TrendSignal
    /// 互动率趋势（engagementTrend 周序列）
    let engagementTrend: TrendSignal
    /// 各类型发帖占比（近 90 天）
    let typeShare: [ContentType: Double]
    /// 最高互动帖（likes + comments）
    let topPostEngagement: Double
    /// 最高互动帖类型
    let topPostType: ContentType?
    /// 最低互动帖（likes + comments）
    let lowestPostEngagement: Double
    /// 低于类型平均 50% 的帖子数
    let lowEngagementPostCount: Int
    /// 零互动帖子数（likes + comments == 0）
    let zeroEngagementPostCount: Int
    /// 距最近一次发帖的天数
    let daysSinceLastPost: Int
    /// 近 7 天发帖数
    let postsLast7d: Int
    /// 连续断更天数（最长无发帖间隔）
    let longestGapDays: Int
    /// 关注数（关注比 = following / followers）
    let followingCount: Int
    /// 草稿数
    let draftCount: Int
    /// 近 7 天净取关天数（快照日增量为负的天数）
    let churnDays7d: Int
    /// 取关最集中的星期（1=周日 … 7=周六）
    let churnPeakDay: Int
    /// 取关高峰日占全部取关的比例（0-1）
    let churnPeakShare: Double
    /// 周末 vs 工作日平均互动差异（周末为正）
    let weekendVsWeekdayRatio: Double
    /// 最佳时段第二窗口（起始小时，无则 nil）
    let secondBestHour: Int?
    /// 第二窗口提升倍数
    let secondBestUplift: Double
    /// 快照天数（数据覆盖度）
    let snapshotCount: Int
    /// 近 30 天周均发帖数（目标频率推导用）
    let avgWeeklyPosts: Double
    /// 账号增长阶段（机会分动态加权用）
    let phase: AccountPhase
}

// MARK: - GrowthFeatures

/// 特征提取结果 — FeatureExtractor 的输出，
/// 聚合内容表现、粉丝健康、疲劳检测等所有可评分维度
struct GrowthFeatures: Sendable {
    /// 各内容类型的表现统计（以 ContentType 为 key）
    let contentPerformance: [ContentType: ContentStats]
    /// 粉丝健康度快照
    let followerHealth: FollowerHealth
    /// 各内容类型的疲劳检测指标（以 ContentType 为 key）
    let fatigueIndices: [ContentType: FatigueIndex]
    /// 量化收益摘要（真实数据推导，用于卡片收益数字）
    let impact: ImpactSummary
    /// 决策上下文（模板触发特征）
    let context: DecisionContext
}
