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
        static let recentContent = "dashboard.recentContent"
        static let viewAll = "dashboard.viewAll"
        static let noPostsHint = "dashboard.noPostsHint"
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
    }
    
    // MARK: Settings
    enum Settings {
        static let title = "settings.title"
        static let trialStatus = "settings.trialStatus"
        static let trialActive = "settings.trialActive"
        static let trialEnded = "settings.trialEnded"
        static let accounts = "settings.accounts"
        static let appearance = "settings.appearance"
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let appleNative = "settings.appleNative"
        static let instagram = "settings.instagram"
        static let appleDark = "settings.appleDark"
        static let forest = "settings.forest"
        static let roseGold = "settings.roseGold"
        static let monoStone = "settings.monoStone"
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
        static let yourBestPostingTime = "premium.yourBestPostingTime"
        static let hourlyHeatmap = "premium.hourlyHeatmap"
        static let lowEngagement = "premium.lowEngagement"
        static let highEngagement = "premium.highEngagement"

        // MARK: Prediction
        static let predictedFollowersNext = "premium.predictedFollowersNext"
        static let predictionDescription = "premium.predictionDescription"

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
    }
}
