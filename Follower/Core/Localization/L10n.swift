//
//  L10n.swift
//  Follower
//
//  统一文本访问入口。通过 LanguageStore 的 per-language Bundle 查找翻译。

import Foundation

// MARK: - loc()

/// 根据当前 App 内选择的语言返回翻译文本。
/// LanguageStore 切换语言时自动切换 Bundle，loc() 即时反映新语言。
func loc(_ key: String, comment: String = "") -> String {
    LanguageStore.shared.localizedString(key)
}

// MARK: - L10n Keys

/// 本地化 Key 枚举 — 按 UI 区域分组，所有文本通过 loc() 查找
enum L10n {
    
    // MARK: Common
    enum Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let done = "common.done"
        static let delete = "common.delete"
        static let loading = "common.loading"
        static let error = "common.error"
        static let retry = "common.retry"
        static let syncNow = "common.syncNow"
        static let share = "common.share"
    }
    
    // MARK: Tab
    enum Tab {
        static let dashboard = "tab.dashboard"
        static let trends = "tab.trends"
        static let settings = "tab.settings"
        static let my = "tab.my"
        static let profile = "tab.profile"
    }
    
    // MARK: Dashboard
    enum Dashboard {
        static let title = "dashboard.title"
        static let noAccountTitle = "dashboard.noAccount.title"
        static let noAccountMessage = "dashboard.noAccount.message"
        static let connectAccount = "dashboard.connectAccount"
        static let noDataTitle = "dashboard.noData.title"
        static let noDataMessage = "dashboard.noData.message"
        static let followers = "dashboard.followers"
        static let following = "dashboard.following"
        static let media = "dashboard.media"
        static let engagementRate = "dashboard.engagementRate"
        static let likes = "dashboard.likes"
        static let comments = "dashboard.comments"
        static let shares = "dashboard.shares"
        static let views = "dashboard.views"
        static let avgLikes = "dashboard.avgLikes"
        static let avgComments = "dashboard.avgComments"
        static let recentContent = "dashboard.recentContent"
        static let viewAll = "dashboard.viewAll"
        static let noPostsHint = "dashboard.noPostsHint"
        
        // ── v3 新增 ──
        static let accountType = "dashboard.accountType"
        static let followersTotal = "dashboard.followersTotal"
        static let reach = "dashboard.reach"
        static let posts = "dashboard.posts"
        static let growthInsights = "dashboard.growthInsights"
        static let growthPositiveHeadline = "dashboard.growthPositiveHeadline"
        static let growthNegativeHeadline = "dashboard.growthNegativeHeadline"
        static let growthNeutralHeadline = "dashboard.growthNeutralHeadline"
        static let growthDefaultDetail = "dashboard.growthDefaultDetail"
        static let followerForecast30d = "dashboard.followerForecast30d"
        static let contentSuggestions = "dashboard.contentSuggestions"
    }
    
    // MARK: Trends
    enum Trends {
        static let title = "trends.title"
        static let daily = "trends.daily"
        static let weekly = "trends.weekly"
        static let monthly = "trends.monthly"
        static let yearly = "trends.yearly"
        static let followers = "trends.followers"
        static let engagement = "trends.engagement"
        static let likes = "trends.likes"
        static let comments = "trends.comments"
        static let shares = "trends.shares"
        static let views = "trends.views"
        static let reach = "trends.reach"
        static let change = "trends.change"
        static let growth = "trends.growth"
        static let noData = "trends.noData"
        static let noDataHint = "trends.noDataHint"
        static let today = "trends.today"
        static let thisWeek = "trends.thisWeek"
    }
    
    // MARK: Settings
    enum Settings {
        static let activityStatus = "settings.activityStatus"
        static let personalization = "settings.personalization"
        static let title = "settings.title"
        static let trialStatus = "settings.trialStatus"
        static let trialActive = "settings.trialActive"
        static let trialEnded = "settings.trialEnded"
        static let accounts = "settings.accounts"
        static let appearance = "settings.appearance"
        static let theme = "settings.theme"
        static let darkMode = "settings.darkMode"
        static let language = "settings.language"
        static let appleNative = "settings.appleNative"
        static let instagram = "settings.instagram"
        static let appleDark = "settings.appleDark"
        static let forest = "settings.forest"
        static let monoStone = "settings.monoStone"
        static let purple = "settings.purple"
        static let instagramDark = "settings.instagramDark"
        static let cream = "settings.cream"
        static let pureBlack = "settings.pureBlack"
        static let dataExport = "settings.dataExport"
        static let format = "settings.format"
        static let exportData = "settings.exportData"
        static let shareExport = "settings.shareExport"
        static let exportFooter = "settings.exportFooter"
        static let storage = "settings.storage"
        static let localOnly = "settings.localOnly"
        static let storageDescription = "settings.storageDescription"
        static let privacy = "settings.privacy"
        static let privacyPolicy = "settings.privacyPolicy"
        static let deleteAllData = "settings.deleteAllData"
        static let deleteConfirmationTitle = "settings.deleteConfirmation.title"
        static let deleteConfirmationMessage = "settings.deleteConfirmation.message"
        static let premiumFeatures = "settings.premiumFeatures"
    }
    
    // MARK: Account
    enum Account {
        static let title = "account.title"
        static let profileTitle = "account.profileTitle"
        static let connectedAccounts = "account.connectedAccounts"
        static let addAccount = "account.addAccount"
        static let connectNew = "account.connectNew"
        static let platform = "account.platform"
        static let username = "account.username"
        static let displayName = "account.displayName"
        static let connect = "account.connect"
        static let revoke = "account.revoke"
        static let cancel = "account.cancel"
        static let footerHint = "account.footerHint"
        static let authorized = "account.authorized"
        static let expired = "account.expired"
        static let revoked = "account.revoked"
        static let instagram = "account.instagram"
        static let tiktok = "account.tiktok"
        static let requiredFields = "account.requiredFields"
        static let noAccountSelected = "account.noAccountSelected"
    }
    
    // MARK: Decisions
    enum Decisions {
        /// 页面标题 / 导航栏标题
        static let title = "decisions.title"
        /// 无决策时的空状态提示
        static let noDecisions = "decisions.noDecisions"
        /// Tab 栏标签
        static let tabDecisions = "decisions.tab"
        /// 无账号空状态标题
        static let noAccountTitle = "decisions.noAccountTitle"
        /// 无账号空状态说明
        static let noAccountMessage = "decisions.noAccountMessage"
        /// 有账号无数据标题
        static let noDataTitle = "decisions.noDataTitle"
        /// 有账号无数据说明
        static let noDataMessage = "decisions.noDataMessage"

        // MARK: Card titles
        /// 主行动卡片标题 — 今日增长加速
        static let boostGrowth = "decisions.boostGrowth"
        /// 提醒卡片标题 — 内容疲劳
        static let contentFatigue = "decisions.contentFatigue"
        /// 恢复卡片标题 — 互动恢复
        static let engagementRecovery = "decisions.engagementRecovery"
        /// 洞察卡片标题 — 最佳发帖时间
        static let bestPostingTime = "decisions.bestPostingTime"
        static let insightContent = "decisions.insightContent"
        static let insightEngagement = "decisions.insightEngagement"
        static let insightGrowth = "decisions.insightGrowth"

        // MARK: Card actions
        /// 推荐行动 — 发布特定内容类型
        static let actionPostType = "decisions.actionPostType"
        /// 推荐行动 — 与高价值粉丝互动
        static let actionEngageFollowers = "decisions.actionEngageFollowers"
        /// 推荐行动 — 回复热门评论
        static let actionReplyComments = "decisions.actionReplyComments"
        /// 推荐行动 — 减少特定类型的帖子
        static let actionReducePosts = "decisions.actionReducePosts"
        /// 推荐行动 — 私信活跃支持者
        static let actionDMSupporters = "decisions.actionDMSupporters"
        /// 推荐行动 — 重新互动热门评论者
        static let actionReengage = "decisions.actionReengage"
        /// 推荐行动 — 安排在特定时间发帖
        static let actionSchedule = "decisions.actionSchedule"

        // MARK: Card reasons
        /// 原因 — Reel 表现优于其他格式
        static let reasonReelOutperform = "decisions.reasonReelOutperform"
        /// 原因 — 内容表现下降，发布频率过高
        static let reasonPerformanceDeclining = "decisions.reasonPerformanceDeclining"
        /// 原因 — 粉丝不活跃
        static let reasonInactiveFollowers = "decisions.reasonInactiveFollowers"
        /// 原因 — 受众在特定时间最活跃
        static let reasonAudienceActive = "decisions.reasonAudienceActive"

        // MARK: Card impacts
        /// 效果 — 增长加速
        static let impactBoost = "decisions.impactBoost"
        /// 效果 — 互动恢复
        static let impactRecovery = "decisions.impactRecovery"
        /// 效果 — 互动率提升
        static let impactEngagement = "decisions.impactEngagement"

        // MARK: Detail view
        /// 详情页 — 推荐行动
        static let recommendedActions = "decisions.recommendedActions"
        /// 详情页 — 原因
        static let why = "decisions.why"
        /// 详情页 — 预期效果
        static let expectedImpact = "decisions.expectedImpact"
        /// 详情页 — 详情
        static let details = "decisions.details"
        /// 标签 — 下降中
        static let declining = "decisions.declining"
        /// 标签 — 增长中
        static let growing = "decisions.growing"

        // MARK: UI labels
        /// 布局方案 — 堆叠
        static let stack = "decisions.stack"
        /// 布局方案 — 时间线
        static let timeline = "decisions.timeline"
        /// 布局方案 — 网格
        static let grid = "decisions.grid"
        /// 布局方案 — 轮播
        static let carousel = "decisions.carousel"
        /// 布局方案 — 列表
        static let list = "decisions.list"

        // MARK: Primary titles (context-aware)
        static let primaryBoostTitle = "decisions.primaryBoostTitle"
        static let primaryReverseTitle = "decisions.primaryReverseTitle"
        static let primarySustainTitle = "decisions.primarySustainTitle"

        // MARK: Alert titles (severity-aware)
        static let alertMildTitle = "decisions.alertMildTitle"
        static let alertSevereTitle = "decisions.alertSevereTitle"

        // MARK: Recovery titles (severity-aware)
        static let recoveryModerateTitle = "decisions.recoveryModerateTitle"
        static let recoveryCriticalTitle = "decisions.recoveryCriticalTitle"

        // MARK: Actions (context-specific)
        static let actionDoubleDown = "decisions.actionDoubleDown"
        static let actionEngageTopFans = "decisions.actionEngageTopFans"
        static let actionTryFormat = "decisions.actionTryFormat"
        static let actionReplyAll = "decisions.actionReplyAll"
        static let actionCrossPromote = "decisions.actionCrossPromote"
        static let actionOptimizeTiming = "decisions.actionOptimizeTiming"
        static let actionTestVariation = "decisions.actionTestVariation"
        static let actionStopType = "decisions.actionStopType"
        static let actionDiversifyFrom = "decisions.actionDiversifyFrom"
        static let actionDMFollowers = "decisions.actionDMFollowers"
        static let actionRunGiveaway = "decisions.actionRunGiveaway"
        static let actionAskEngagement = "decisions.actionAskEngagement"

        // MARK: Reasons (context-specific)
        static let reasonMomentum = "decisions.reasonMomentum"
        static let reasonDeclining = "decisions.reasonDeclining"
        static let reasonFatigueSevere = "decisions.reasonFatigueSevere"
        static let reasonCriticalInactive = "decisions.reasonCriticalInactive"

        // MARK: Impacts (context-specific)
        static let impactReverse = "decisions.impactReverse"
        static let impactOptimize = "decisions.impactOptimize"
        static let impactCritical = "decisions.impactCritical"

        // MARK: Quantified impact (v1 — 与涨粉/浏览挂钩的量化收益)
        /// 量化收益 — 粉丝 + 浏览："+69 粉丝 · +1.2K 浏览"
        static let impactFansViews = "decisions.impactFansViews"
        /// 量化收益 — 仅粉丝："+69 粉丝"
        static let impactFansOnly = "decisions.impactFansOnly"
        /// 量化收益 — 仅浏览："+1.2K 浏览"
        static let impactViewsOnly = "decisions.impactViewsOnly"
        /// 原因 — 时段互动提升倍数："在 周四 19:00 发帖的互动是平均水平的 1.4 倍"
        static let reasonTimeUplift = "decisions.reasonTimeUplift"

        // MARK: v2/v3 UI（Hero 区 / 分类标签 / 折叠区 / 空态）
        /// Hero — 当前粉丝
        static let heroFollowers = "decisions.heroFollowers"
        /// Hero — 7 日涨粉
        static let heroGrowth7d = "decisions.heroGrowth7d"
        /// Hero — 7 日浏览
        static let heroViews7d = "decisions.heroViews7d"
        /// 建议列表区标题 — 今日建议
        static let todayActions = "decisions.todayActions"
        /// Hero — 数据时间戳（基于 %@ 数据）
        static let basedOnData = "decisions.basedOnData"
        /// 分类标签 — 内容
        static let tagContent = "decisions.tagContent"
        /// 分类标签 — 时间
        static let tagTiming = "decisions.tagTiming"
        /// 分类标签 — 增长
        static let tagGrowth = "decisions.tagGrowth"
        /// 分类标签 — 互动
        static let tagEngagement = "decisions.tagEngagement"
        /// 分类标签 — 触达
        static let tagReach = "decisions.tagReach"
        /// 分类标签 — 健康
        static let tagHealth = "decisions.tagHealth"
        /// 分类标签 — 运营
        static let tagOps = "decisions.tagOps"
        /// 行动按钮 — 采取行动
        static let takeAction = "decisions.takeAction"
        /// 低置信标签 — 估算
        static let estimation = "decisions.estimation"
        /// 空态说明 — 暂无建议
        static let noDecisionsMessage = "decisions.noDecisionsMessage"
    }

    // MARK: Premium Insights
    enum Premium {
        // MARK: Section header
        static let premiumInsights = "premium.insights"

        // MARK: Card titles (Dashboard)
        static let followerPrediction = "premium.followerPrediction"
        static let activityAnalysis = "premium.activityAnalysis"
        static let engagementQuality = "premium.engagementQuality"
        static let retentionChurn = "premium.retentionChurn"
        static let geoDistribution = "premium.geoDistribution"
        static let longTermComparison = "premium.longTermComparison"
        static let whoUnfollowedYou = "premium.whoUnfollowedYou"
        static let bestTimeToPost = "premium.bestTimeToPost"
        static let contentStrategy = "premium.contentStrategy"

        // MARK: Best Time v2（推荐 + 置信度 + 证据）
        /// 评分数字（%@ = 0-100）
        static let bestTimeScore = "premium.bestTimeScore"
        /// 评分标签
        static let bestTimeScoreLabel = "premium.bestTimeScoreLabel"
        /// 置信度标签
        static let bestTimeConfidenceLabel = "premium.bestTimeConfidenceLabel"
        /// 相对基线提升标签
        static let bestTimeLiftLabel = "premium.bestTimeLiftLabel"
        /// 置信度分档
        static let confidenceLow = "premium.confidenceLow"
        static let confidenceMedium = "premium.confidenceMedium"
        static let confidenceHigh = "premium.confidenceHigh"
        /// Why 卡标题
        static let bestTimeWhyTitle = "premium.bestTimeWhyTitle"
        /// 相对基线提升说明
        static let bestTimeLiftDesc = "premium.bestTimeLiftDesc"
        /// 样本说明（%@ = 窗口样本，%d = 总帖数）："%@ 篇帖子分析（窗口内 %@ 篇）"
        static let bestTimeSamples = "premium.bestTimeSamples"
        /// 最佳窗口概率
        static let bestTimeProbability = "premium.bestTimeProbability"
        /// 历史表现卡标题
        static let bestTimeHistoricalTitle = "premium.bestTimeHistoricalTitle"

        // MARK: Card value snippets
        static let analyzing = "premium.analyzing"
        static let in30Days = "premium.in30Days"
        static let daysActive = "premium.daysActive"
        static let peopleThisWeek = "premium.peopleThisWeek"
        static let mostActiveDay = "premium.mostActiveDay"

        // MARK: Activity Detail
        static let activityLevel = "premium.activityLevel"
        static let activeDaysRatio = "premium.activeDaysRatio"
        static let avgEventsPerDay = "premium.avgEventsPerDay"
        static let bestDay = "premium.bestDay"
        static let noDataActivity = "premium.noDataActivity"
        static let noDataActivityDesc = "premium.noDataActivityDesc"

        // MARK: Activity labels
        static let highlyActive = "premium.highlyActive"
        static let active = "premium.active"
        static let moderate = "premium.moderate"
        static let lowActivity = "premium.lowActivity"
        static let tipHighlyActive = "premium.tipHighlyActive"
        static let tipActive = "premium.tipActive"
        static let tipModerate = "premium.tipModerate"
        static let tipLowActivity = "premium.tipLowActivity"

        // MARK: Retention Detail
        static let netGrowthRate = "premium.netGrowthRate"
        static let churnRiskLevel = "premium.churnRiskLevel"
        static let churnDetected = "premium.churnDetected"
        static let start = "premium.start"
        static let end = "premium.end"
        static let avgDailyChange = "premium.avgDailyChange"
        static let noDataRetention = "premium.noDataRetention"
        static let noDataRetentionDesc = "premium.noDataRetentionDesc"

        // MARK: Churn risk levels
        static let churnNone = "premium.churnNone"
        static let churnLow = "premium.churnLow"
        static let churnMedium = "premium.churnMedium"
        static let churnHigh = "premium.churnHigh"
        static let tipChurnNone = "premium.tipChurnNone"
        static let tipChurnLow = "premium.tipChurnLow"
        static let tipChurnMedium = "premium.tipChurnMedium"
        static let tipChurnHigh = "premium.tipChurnHigh"

        // MARK: Quality Detail
        static let qualityScore = "premium.qualityScore"
        static let engagementRate = "premium.engagementRate"
        static let weightBreakdown = "premium.weightBreakdown"
        static let weightBreakdownDesc = "premium.weightBreakdownDesc"
        static let likes = "premium.likes"
        static let comments = "premium.comments"
        static let shares = "premium.shares"
        static let noDataQuality = "premium.noDataQuality"
        static let noDataQualityDesc = "premium.noDataQualityDesc"

        // MARK: Quality labels
        static let excellent = "premium.excellent"
        static let great = "premium.great"
        static let good = "premium.good"
        static let fair = "premium.fair"
        static let lowQuality = "premium.lowQuality"
        static let tipExcellent = "premium.tipExcellent"
        static let tipGreat = "premium.tipGreat"
        static let tipGood = "premium.tipGood"
        static let tipFair = "premium.tipFair"
        static let tipLowQuality = "premium.tipLowQuality"

        // MARK: Geo Detail
        static let topRegion = "premium.topRegion"
        static let distributionByRegion = "premium.distributionByRegion"
        static let noDataGeo = "premium.noDataGeo"
        static let noDataGeoDesc = "premium.noDataGeoDesc"

        // MARK: Comparison Detail
        static let previousPeriod = "premium.previousPeriod"
        static let currentPeriod = "premium.currentPeriod"
        static let absoluteChange = "premium.absoluteChange"
        static let noDataComparison = "premium.noDataComparison"
        static let noDataComparisonDesc = "premium.noDataComparisonDesc"

        // MARK: Comparison directions
        static let growing = "premium.growing"
        static let declining = "premium.declining"
        static let stable = "premium.stable"
        static let tipStable = "premium.tipStable"

        // MARK: Best Time
        static let hourlyEngagement = "premium.hourlyEngagement"
        static let dailyEngagement = "premium.dailyEngagement"
        static let bubbleMatrix = "premium.bubbleMatrix"
        static let bubbleLegend = "premium.bubbleLegend"
        static let basedOnPosts = "premium.basedOnPosts"
        static let avgEngagementPerPost = "premium.avgEngagementPerPost"
        static let noDataBestTime = "premium.noDataBestTime"
        static let noDataBestTimeDesc = "premium.noDataBestTimeDesc"

        // MARK: Prediction
        static let predictedFollowersNext = "premium.predictedFollowersNext"
        static let predictionDescription = "premium.predictionDescription"
        /// 预计增长标签（v1.4）
        static let predictedGrowthLabel = "premium.predictedGrowthLabel"

        // MARK: No data generic
        static let noDataAvailable = "premium.noDataAvailable"

        // MARK: Day names (short, for activity)
        static let daySun = "premium.daySun"
        static let dayMon = "premium.dayMon"
        static let dayTue = "premium.dayTue"
        static let dayWed = "premium.dayWed"
        static let dayThu = "premium.dayThu"
        static let dayFri = "premium.dayFri"
        static let daySat = "premium.daySat"
        static let scheduledAt = "premium.scheduledAt"
        static let breakdown = "premium.breakdown"
        static let regionsWithAudience = "premium.regionsWithAudience"

        // MARK: Existing keys (keep for backward compatibility)
        static let premiumFeature = "premium.feature"
        static let upgradeTitle = "premium.upgradeTitle"
        static let upgradeTo = "premium.upgradeTo"
        static let comingSoon = "premium.comingSoon"
        static let trialActive = "premium.trialActive"
        static let trialBadge = "premium.trialBadge"
        static let trialRemaining = "premium.trialRemaining"
        static let trialEnded = "premium.trialEnded"
        static let close = "premium.close"
        static let benefit1 = "premium.benefit1"
        static let benefit2 = "premium.benefit2"
        static let benefit3 = "premium.benefit3"
        static let benefit4 = "premium.benefit4"
        static let benefit5 = "premium.benefit5"
        static let unlockAll = "premium.unlockAll"
        static let unlocked = "premium.unlocked"
        static let unfollowed = "premium.unfollowed"

        // MARK: - Phi: 三大人群画像 Premium 功能
        static let competitorComparison = "premium.competitorComparison"
        static let authenticityAssessment = "premium.authenticityAssessment"
        static let mediaKitExport = "premium.mediaKitExport"
        static let campaignTracking = "premium.campaignTracking"
        static let engagementHeatmap = "premium.engagementHeatmap"
        static let contentScheduling = "premium.contentScheduling"
        static let commentManagement = "premium.commentManagement"
        static let themeSwitching = "premium.themeSwitching"

        // MARK: - Phi: Detail view labels
        static let competitorGrowth = "premium.competitorGrowth"
        static let competitorYou = "premium.competitorYou"
        static let competitorPeersAvg = "premium.competitorPeersAvg"
        static let competitorDesc = "premium.competitorDesc"
        static let trend = "premium.trend"
        static let followers = "premium.followers"
        static let engagement = "premium.engagement"

        static let authenticityScore = "premium.authenticityScore"
        static let growthPattern = "premium.growthPattern"
        static let followerAuthenticity = "premium.followerAuthenticity"
        static let anomalyDetection = "premium.anomalyDetection"
        static let normal = "premium.normal"
        static let noAnomalies = "premium.noAnomalies"
        static let authenticityDesc = "premium.authenticityDesc"

        static let templateProfessional = "premium.templateProfessional"
        static let templateCreative = "premium.templateCreative"
        static let templateMinimal = "premium.templateMinimal"
        static let mediaKit = "premium.mediaKit"
        static let readyToExport = "premium.readyToExport"
        static let template = "premium.template"
        static let includes = "premium.includes"
        static let mkFollowerGrowth = "premium.mkFollowerGrowth"
        static let mkEngagementHistory = "premium.mkEngagementHistory"
        static let mkAudience = "premium.mkAudience"
        static let mkTopPosts = "premium.mkTopPosts"
        static let mkContact = "premium.mkContact"
        static let exportPDF = "premium.exportPDF"

        static let preCampaign = "premium.preCampaign"
        static let postCampaign = "premium.postCampaign"
        static let campaignImpact = "premium.campaignImpact"
        static let newFollowers = "premium.newFollowers"
        static let growthRate = "premium.growthRate"
        static let campaignDesc = "premium.campaignDesc"

        static let heatmapDesc = "premium.heatmapDesc"

        static let activityDistribution = "premium.activityDistribution"
        static let periodDistribution = "premium.periodDistribution"
        static let weekdayDistribution = "premium.weekdayDistribution"
        static let totalEvents = "premium.totalEvents"
        static let periodNight = "premium.periodNight"
        static let periodMorning = "premium.periodMorning"
        static let periodAfternoon = "premium.periodAfternoon"
        static let periodEvening = "premium.periodEvening"

        static let next3Days = "premium.next3Days"
        static let reasonPeakEngagement = "premium.reasonPeakEngagement"
        static let reasonLunchtime = "premium.reasonLunchtime"
        static let reasonStartOfWeek = "premium.reasonStartOfWeek"
        static let schedulingDesc = "premium.schedulingDesc"

        static let pending = "premium.pending"
        static let over24h = "premium.over24h"
        static let replied = "premium.replied"
        static let hoursAgo = "premium.hoursAgo"
        static let commentMgmtDesc = "premium.commentMgmtDesc"

        // MARK: - Content strategy tips
        static let strategyCarousel = "premium.strategyCarousel"
        static let strategyCarouselDesc = "premium.strategyCarouselDesc"
        static let strategyVideo = "premium.strategyVideo"
        static let strategyVideoDesc = "premium.strategyVideoDesc"
        static let strategyFrequency = "premium.strategyFrequency"
        static let strategyFrequencyDesc = "premium.strategyFrequencyDesc"
        static let strategyHashtag = "premium.strategyHashtag"
        static let strategyHashtagDesc = "premium.strategyHashtagDesc"
        static let strategyEngage = "premium.strategyEngage"
        static let strategyEngageDesc = "premium.strategyEngageDesc"

        // MARK: - Detail views (v0.16 补缺：其余详情页 key 见上方各 Detail 分组)
        static let likelyRange80 = "premium.likelyRange80"
        static let growthProbability = "premium.growthProbability"
        /// 95% 预测区间标签（v1.6 Tooltip）
        static let likelyRange95 = "premium.likelyRange95"
        /// Tooltip 预计值标签（v1.6）
        static let predictionForecast = "premium.predictionForecast"
        static let predictionUnavailable = "premium.predictionUnavailable"
        static let predictionNeedsData = "premium.predictionNeedsData"
        static let comparisonUp = "premium.comparisonUp"
        static let comparisonDown = "premium.comparisonDown"
        static let comparisonStable = "premium.comparisonStable"
        static let anomalies = "premium.anomalies"
        static let activeDaysOf = "premium.activeDaysOf"
    }

    // MARK: MediaKit（媒体包 PDF 导出）
    enum MediaKit {
        // 指标标签
        static let followers = "mediakit.followers"
        static let posts = "mediakit.posts"
        static let engagementRate = "mediakit.engagementRate"
        static let avgLikes = "mediakit.avgLikes"
        static let avgComments = "mediakit.avgComments"
        static let avgShares = "mediakit.avgShares"
        static let profileViews = "mediakit.profileViews"

        // 封面
        static let generatedBy = "mediakit.generatedBy"
        static let businessAccount = "mediakit.businessAccount"
        static let creatorAccount = "mediakit.creatorAccount"
        static let personalAccount = "mediakit.personalAccount"

        // 核心指标页
        static let coreMetrics = "mediakit.coreMetrics"
        static let coreMetricsSubtitle = "mediakit.coreMetricsSubtitle"

        // 增长趋势页
        static let growthTrend = "mediakit.growthTrend"
        static let growthTrendSubtitle = "mediakit.growthTrendSubtitle"
        static let growthSummary = "mediakit.growthSummary"

        // 内容表现页
        static let contentPerformance = "mediakit.contentPerformance"
        static let contentPerformanceSubtitle = "mediakit.contentPerformanceSubtitle"
        static let topPosts = "mediakit.topPosts"
        static let postTypeDistribution = "mediakit.postTypeDistribution"
        static let typeImage = "mediakit.typeImage"
        static let typeVideo = "mediakit.typeVideo"
        static let typeCarousel = "mediakit.typeCarousel"

        // 互动质量页
        static let engagementQuality = "mediakit.engagementQuality"
        static let engagementQualitySubtitle = "mediakit.engagementQualitySubtitle"

        // 趋势柱状页
        static let trendBars = "mediakit.trendBars"
        static let trendBarsSubtitle = "mediakit.trendBarsSubtitle"

        // 趋势统计页
        static let trendStats = "mediakit.trendStats"
        static let trendStatsSubtitle = "mediakit.trendStatsSubtitle"

        // 增长建议页
        static let decisions = "mediakit.decisions"
        static let decisionsSubtitle = "mediakit.decisionsSubtitle"

        // 模板说明
        static let templateProfessionalDesc = "mediakit.templateProfessionalDesc"
        static let templateCreativeDesc = "mediakit.templateCreativeDesc"
        static let templateMinimalDesc = "mediakit.templateMinimalDesc"

        // 结语页
        static let dataNotes = "mediakit.dataNotes"
        static let dataNotesSubtitle = "mediakit.dataNotesSubtitle"
        static let note1 = "mediakit.note1"
        static let note2 = "mediakit.note2"
        static let note3 = "mediakit.note3"
        static let note4 = "mediakit.note4"

        // 错误与 UI 入口
        static let accountNotFound = "mediakit.accountNotFound"
        static let generateMediaKit = "mediakit.generateMediaKit"
        static let mediaKitSection = "mediakit.mediaKitSection"
        static let mediaKitDescription = "mediakit.mediaKitDescription"
    }
}

// MARK: Decision Templates (v3 — 41 个 P0 模板)
/// 模板文案 key — 标题（每模板独立）/ 原因与行动（按模式共享）
enum Tpl {
    // MARK: Titles (41)
    enum Title {
        static let boostTopType = "tpl.boostTopType.title"
        static let rescueDecliningType = "tpl.rescueDecliningType.title"
        static let replicateViral = "tpl.replicateViral.title"
        static let lowEngagementDiagnosis = "tpl.lowEngagementDiagnosis.title"
        static let diversifyTypes = "tpl.diversifyTypes.title"
        static let carouselForLongContent = "tpl.carouselForLongContent.title"
        static let increaseFrequency = "tpl.increaseFrequency.title"
        static let reduceFrequency = "tpl.reduceFrequency.title"
        static let balanceWeeklyCadence = "tpl.balanceWeeklyCadence.title"
        static let testSecondBestType = "tpl.testSecondBestType.title"
        static let typeTrendWarning = "tpl.typeTrendWarning.title"
        static let guideComments = "tpl.guideComments.title"
        static let bestHour = "tpl.bestHour.title"
        static let bestDay = "tpl.bestDay.title"
        static let secondBestHour = "tpl.secondBestHour.title"
        static let avoidWorstHours = "tpl.avoidWorstHours.title"
        static let weekdayVsWeekend = "tpl.weekdayVsWeekend.title"
        static let growthSlowdown = "tpl.growthSlowdown.title"
        static let inactiveWakeup = "tpl.inactiveWakeup.title"
        static let churnWarning = "tpl.churnWarning.title"
        static let churnPeakDay = "tpl.churnPeakDay.title"
        static let conversionBoost = "tpl.conversionBoost.title"
        static let followerQuality = "tpl.followerQuality.title"
        static let topFansEngage = "tpl.topFansEngage.title"
        static let growthTarget = "tpl.growthTarget.title"
        static let engagementDecline = "tpl.engagementDecline.title"
        static let replyComments = "tpl.replyComments.title"
        static let qAndA = "tpl.qAndA.title"
        static let shareRateLow = "tpl.shareRateLow.title"
        static let viralFollowUp = "tpl.viralFollowUp.title"
        static let reachDecline = "tpl.reachDecline.title"
        static let profileViewsBoost = "tpl.profileViewsBoost.title"
        static let reachWasted = "tpl.reachWasted.title"
        static let stablePublishing = "tpl.stablePublishing.title"
        static let followingRatioHigh = "tpl.followingRatioHigh.title"
        static let draftBacklog = "tpl.draftBacklog.title"
        static let postingGap = "tpl.postingGap.title"
        static let dataCoverage = "tpl.dataCoverage.title"
        static let reuseViral = "tpl.reuseViral.title"
        static let monthlyPlan = "tpl.monthlyPlan.title"
        static let seriesContent = "tpl.seriesContent.title"
    }

    // MARK: Reasons (共享模式)
    enum Reason {
        static let perPostGain = "tpl.reason.perPostGain"
        static let typeDeclining = "tpl.reason.typeDeclining"
        static let viral = "tpl.reason.viral"
        static let lowEngage = "tpl.reason.lowEngage"
        static let dominant = "tpl.reason.dominant"
        static let photoWeak = "tpl.reason.photoWeak"
        static let freqLow = "tpl.reason.freqLow"
        static let freqHigh = "tpl.reason.freqHigh"
        static let cadence = "tpl.reason.cadence"
        static let secondType = "tpl.reason.secondType"
        static let typeWarning = "tpl.reason.typeWarning"
        static let highLikesLowComments = "tpl.reason.highLikesLowComments"
        static let hourUplift = "tpl.reason.hourUplift"
        static let dayUplift = "tpl.reason.dayUplift"
        static let secondHour = "tpl.reason.secondHour"
        static let avoidWorst = "tpl.reason.avoidWorst"
        static let weekendVsWeekday = "tpl.reason.weekendVsWeekday"
        static let insufficientData = "tpl.reason.insufficientData"
        static let weekendBetter = "tpl.reason.weekendBetter"
        static let weekdayBetter = "tpl.reason.weekdayBetter"
        static let growthSlowdown = "tpl.reason.growthSlowdown"
        static let inactiveFollowers = "tpl.reason.inactiveFollowers"
        static let churn = "tpl.reason.churn"
        static let churnDay = "tpl.reason.churnDay"
        static let conversion = "tpl.reason.conversion"
        static let lowQuality = "tpl.reason.lowQuality"
        static let topFans = "tpl.reason.topFans"
        static let growthTarget = "tpl.reason.growthTarget"
        static let engagementDecline = "tpl.reason.engagementDecline"
        static let reply = "tpl.reason.reply"
        static let qna = "tpl.reason.qna"
        static let shareRate = "tpl.reason.shareRate"
        static let viralFollowUp = "tpl.reason.viralFollowUp"
        static let reachDecline = "tpl.reason.reachDecline"
        static let profileViews = "tpl.reason.profileViews"
        static let reachWasted = "tpl.reason.reachWasted"
        static let unstablePublishing = "tpl.reason.unstablePublishing"
        static let followingRatio = "tpl.reason.followingRatio"
        static let drafts = "tpl.reason.drafts"
        static let postingGap = "tpl.reason.postingGap"
        static let dataCoverage = "tpl.reason.dataCoverage"
        static let monthlyPlan = "tpl.reason.monthlyPlan"
        static let seriesContent = "tpl.reason.seriesContent"
    }

    // MARK: Actions (共享模式)
    enum Action {
        static let boost = "tpl.action.boost"
        static let tryNewFormat = "tpl.action.tryNewFormat"
        static let replyAll = "tpl.action.replyAll"
        static let analyzeLow = "tpl.action.analyzeLow"
        static let diversify = "tpl.action.diversify"
        static let switchFormat = "tpl.action.switchFormat"
        static let scheduleMore = "tpl.action.scheduleMore"
        static let reduceTo = "tpl.action.reduceTo"
        static let spreadCadence = "tpl.action.spreadCadence"
        static let testOne = "tpl.action.testOne"
        static let pauseType = "tpl.action.pauseType"
        static let askComments = "tpl.action.askComments"
        static let postAtHour = "tpl.action.postAtHour"
        static let postAtDay = "tpl.action.postAtDay"
        static let fillSecond = "tpl.action.fillSecond"
        static let avoidWorst = "tpl.action.avoidWorst"
        static let balanceWeekend = "tpl.action.balanceWeekend"
        static let prioritizeWeekend = "tpl.action.prioritizeWeekend"
        static let prioritizeWeekday = "tpl.action.prioritizeWeekday"
        static let engageTopFans = "tpl.action.engageTopFans"
        static let dmTopFans = "tpl.action.dmTopFans"
        static let runGiveaway = "tpl.action.runGiveaway"
        static let crossPromote = "tpl.action.crossPromote"
        static let encourageShare = "tpl.action.encourageShare"
        static let followUp = "tpl.action.followUp"
        static let checkReach = "tpl.action.checkReach"
        static let optimizeProfile = "tpl.action.optimizeProfile"
        static let stabilize = "tpl.action.stabilize"
        static let unfollowClean = "tpl.action.unfollowClean"
        static let publishDrafts = "tpl.action.publishDrafts"
        static let postNow = "tpl.action.postNow"
        static let syncMore = "tpl.action.syncMore"
        static let reuseViral = "tpl.action.reuseViral"
        static let monthlyPlan = "tpl.action.monthlyPlan"
        static let qna = "tpl.action.qna"
    }
}
