//
//  PremiumFeatureDetailViews.swift
//  Follower
//
//  Phi: 三大人群画像 Premium 功能详情页。
//  所有数据由 DashboardViewModel 的真实服务计算结果提供。
//  文案通过 L10n 本地化（en / ja / zh-Hans / zh-Hant）。
//

import SwiftUI

// MARK: - 竞品对比详情

/// Premium 详情页：同类账号粉丝与互动率均值对比（使用长期趋势对比数据）
struct CompetitorDetailView: View {
    @Environment(\.theme) private var theme
    let comparisonResult: ComparisonResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = comparisonResult {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: competitorIcon(for: result.direction))
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(competitorColor(for: result.direction))
                                Text(String(format: "%+.2f", result.absoluteChange))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(competitorColor(for: result.direction))
                            }
                            Text(loc(L10n.Premium.competitorGrowth))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        // 前/当前周期均值双条对比
                        DualBarCompareView(
                            title: loc(L10n.Premium.competitorPeersAvg),
                            leftLabel: loc(L10n.Premium.previousPeriod),
                            leftValue: result.previousAvg,
                            leftColor: theme.textSecondary,
                            rightLabel: loc(L10n.Premium.currentPeriod),
                            rightValue: result.currentAvg,
                            rightColor: competitorColor(for: result.direction)
                        )

                        Text(loc(L10n.Premium.competitorDesc))
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    noDataView
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.competitorComparison))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 根据对比方向返回 SF Symbol 图标名
    private func competitorIcon(for direction: ComparisonDirection) -> String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "equal"
        }
    }

    /// 根据对比方向返回颜色
    private func competitorColor(for direction: ComparisonDirection) -> Color {
        switch direction {
        case .up: return theme.positiveGreen
        case .down: return theme.negativeRed
        case .flat: return theme.textSecondary
        }
    }

    private var noDataView: some View {
        ContentUnavailableView(
            loc(L10n.Premium.noDataAvailable),
            systemImage: "chart.bar.fill",
            description: Text(loc(L10n.Premium.noDataComparison))
        )
        .padding(.top, 80)
    }
}

// MARK: - 真实性评估详情

/// Premium 详情页：综合互动质量 + 增长曲线 + 异常检测 → 真实性评分
struct AuthenticityDetailView: View {
    @Environment(\.theme) private var theme
    let result: AuthenticityResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = result {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            ScoreGaugeView(score: result.score, size: 140)
                            Text(loc(L10n.Premium.authenticityScore))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            scoreRow(label: loc(L10n.Premium.engagementQuality),
                                     value: "",
                                     color: scoreColor(result.engagementQuality),
                                     score: result.engagementQuality)
                            scoreRow(label: loc(L10n.Premium.growthPattern),
                                     value: result.growthPattern,
                                     color: result.growthPattern == "Natural" ? theme.positiveGreen : theme.warningOrange)
                            scoreRow(label: loc(L10n.Premium.followerAuthenticity),
                                     value: "",
                                     color: scoreColor(result.followerAuthenticity),
                                     score: result.followerAuthenticity)
                            scoreRow(label: loc(L10n.Premium.anomalyDetection),
                                     value: result.hasAnomalies ? result.anomalyDescription ?? loc(L10n.Premium.anomalies) : loc(L10n.Premium.noAnomalies),
                                     color: result.hasAnomalies ? theme.warningOrange : theme.textSecondary)
                        }
                        .padding()
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        Text(loc(L10n.Premium.authenticityDesc))
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    noDataView
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.authenticityAssessment))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 分数行：小环形仪表 + 标签 + 分数；无分数时退化为纯文本值
    private func scoreRow(label: String, value: String, color: Color, score: Double? = nil) -> some View {
        HStack(spacing: 10) {
            if let score {
                ScoreGaugeView(score: score, size: 36, centerText: String(format: "%.0f", score))
            }
            Text(label).font(.subheadline).foregroundColor(.primary)
            Spacer()
            if let score {
                Text("\(Int(score))/100")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(color)
            } else {
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(color)
            }
        }
    }

    /// 分数档位颜色 — 与 ScoreGaugeView 的 ScoreTier 标准一致（≥80 / ≥60 / ≥40 / <40）
    private func scoreColor(_ score: Double) -> Color {
        switch ScoreTier.tier(for: score) {
        case .excellent: return theme.positiveGreen
        case .good: return theme.accentPrimary
        case .fair: return theme.warningOrange
        case .poor: return theme.negativeRed
        }
    }

    private var noDataView: some View {
        ContentUnavailableView(
            loc(L10n.Premium.noDataAvailable),
            systemImage: "checkmark.shield.fill",
            description: Text(loc(L10n.Premium.noDataQuality))
        )
        .padding(.top, 80)
    }
}

// MARK: - 媒体包导出详情（三模板 + PDF 生成 + 分享）

struct MediaKitDetailView: View {
    @Environment(\.theme) private var theme
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 48)).foregroundColor(theme.accentPrimary)
                        Text(loc(L10n.Premium.mediaKit)).font(.title2).fontWeight(.bold)
                        Text(loc(L10n.Premium.readyToExport)).font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding().frame(maxWidth: .infinity)
                    .background(theme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal)

                    // 模板选择：segmented + 当前模板说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc(L10n.Premium.template)).font(.headline).padding(.horizontal)
                        Picker(loc(L10n.Premium.template), selection: $viewModel.selectedMediaKitTemplate) {
                            ForEach(MediaKitTemplate.allCases) { template in
                                Text(template.displayName).tag(template)
                            }
                        }
                        .pickerStyle(.segmented).padding(.horizontal)
                        Text(viewModel.selectedMediaKitTemplate.detailDescription)
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc(L10n.Premium.includes)).font(.headline)
                        ForEach([
                            loc(L10n.Premium.mkFollowerGrowth),
                            loc(L10n.Premium.mkEngagementHistory),
                            loc(L10n.Premium.mkAudience),
                            loc(L10n.Premium.mkTopPosts),
                            loc(L10n.Premium.mkContact)
                        ], id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill").foregroundColor(theme.positiveGreen)
                        }
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)

                    // 生成 + 分享
                    if let url = viewModel.mediaKitURL {
                        ShareLink(item: url) {
                            Label(loc(L10n.Common.share), systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(theme.positiveGreen).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    Button {
                        Task { await viewModel.generateMediaKit() }
                    } label: {
                        if viewModel.isGeneratingMediaKit {
                            ProgressView().frame(maxWidth: .infinity).padding()
                                .background(theme.accentPrimary.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Label(loc(L10n.MediaKit.generateMediaKit), systemImage: "arrow.down.doc.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(theme.accentPrimary).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .disabled(viewModel.selectedAccountId == nil || viewModel.isGeneratingMediaKit)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.mediaKitExport))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 投放效果跟踪详情

/// Premium 详情页：前后时间段关键指标对比（基于真实 Snapshot 数据）
struct CampaignDetailView: View {
    @Environment(\.theme) private var theme
    let result: CampaignResult?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = result {
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            periodCard(
                                label: loc(L10n.Premium.preCampaign),
                                followers: "\(result.preFollowers)",
                                engagement: String(format: "%.1f%%", result.preEngagement),
                                color: theme.textSecondary
                            )
                            Image(systemName: "arrow.right").foregroundColor(.secondary)
                            periodCard(
                                label: loc(L10n.Premium.postCampaign),
                                followers: "\(result.postFollowers)",
                                engagement: String(format: "%.1f%%", result.postEngagement),
                                color: theme.positiveGreen
                            )
                        }
                        .padding(.horizontal)

                        VStack(spacing: 8) {
                            Text(loc(L10n.Premium.campaignImpact)).font(.headline)
                            HStack(spacing: 24) {
                                impactStat(value: formatDelta(result.followerDelta), label: loc(L10n.Premium.newFollowers))
                                impactStat(value: String(format: "%+.1f%%", result.engagementDelta), label: loc(L10n.Premium.engagement))
                                impactStat(value: String(format: "%+.1f%%", result.followerGrowthRate), label: loc(L10n.Premium.growthRate))
                            }
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(theme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)

                        Text(loc(L10n.Premium.campaignDesc))
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    noDataView
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.campaignTracking))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func periodCard(label: String, followers: String, engagement: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(color)
            VStack(spacing: 2) {
                Text(followers).font(.title3).fontWeight(.bold)
                Text(loc(L10n.Premium.followers)).font(.caption2).foregroundColor(.secondary)
            }
            VStack(spacing: 2) {
                Text(engagement).font(.title3).fontWeight(.bold)
                Text(loc(L10n.Premium.engagement)).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding().frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func impactStat(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.title).fontWeight(.bold)
                .foregroundColor(value.hasPrefix("+") ? theme.positiveGreen : theme.negativeRed)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }

    private func formatDelta(_ delta: Int) -> String {
        delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    private var noDataView: some View {
        ContentUnavailableView(
            loc(L10n.Premium.noDataAvailable),
            systemImage: "chart.line.flattrend.xyaxis",
            description: Text(loc(L10n.Premium.noDataComparisonDesc))
        )
        .padding(.top, 80)
    }
}

// MARK: - 互动热力图详情

/// Premium 详情页：互动热力图 — 分布分析视角（与「最佳发帖时间」的决策视角互补）。
/// 展示总事件数、活跃时段分布、一周分布 + 7×24 密度网格；
/// 分布数据由 EngagementHeatmapService 聚合，View 只做展示。
struct HeatmapDetailView: View {
    @Environment(\.theme) private var theme
    let result: EngagementHeatmapResult?

    private var dayLabels: [String] {
        [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
         loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
         loc(L10n.Premium.daySat)]
    }

    /// 时段标签（与 periodDistribution 顺序一致：凌晨/上午/下午/晚上）
    private var periodLabels: [String] {
        [loc(L10n.Premium.periodNight), loc(L10n.Premium.periodMorning),
         loc(L10n.Premium.periodAfternoon), loc(L10n.Premium.periodEvening)]
    }

    /// Sun-first 7×24 密度矩阵（行序与 dayLabels 一致，供 HeatmapGrid 使用）
    private var sunFirstRows: [[Double]] {
        guard let result, !result.cells.isEmpty else {
            return Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        }
        return (1...7).map { wd in
            (0..<24).map { hour in result.density(weekday: wd, hour: hour) }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = result, !result.cells.isEmpty {
                    VStack(spacing: 20) {
                        distributionCard(result)
                        HeatmapGrid(rows: sunFirstRows, dayLabels: dayLabels)
                            .padding().background(theme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)

                        Text(loc(L10n.Premium.heatmapDesc))
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    ContentUnavailableView(
                        loc(L10n.Premium.noDataAvailable),
                        systemImage: "square.grid.3x3.fill",
                        description: Text(loc(L10n.Premium.noDataActivityDesc))
                    )
                    .padding(.top, 80)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.engagementHeatmap))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 互动分布卡片：总事件数 + 时段分布条 + 一周分布条
    private func distributionCard(_ result: EngagementHeatmapResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(loc(L10n.Premium.activityDistribution)).font(.headline)
                Spacer()
                Text(String(format: loc(L10n.Premium.totalEvents), result.totalEvents))
                    .font(.caption).foregroundColor(.secondary)
            }
            Text(loc(L10n.Premium.periodDistribution))
                .font(.subheadline).foregroundColor(.secondary)
            periodBar(values: result.periodDistribution, labels: periodLabels)
            Text(loc(L10n.Premium.weekdayDistribution))
                .font(.subheadline).foregroundColor(.secondary)
            weekdayBar(values: result.dayDistribution, labels: dayLabels)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// 时段分布条：4 段水平条，宽度按占比，最高段高亮
    private func periodBar(values: [Double], labels: [String]) -> some View {
        let maxValue = values.max() ?? 0
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<values.count, id: \.self) { i in
                    let isMax = values[i] > 0 && values[i] >= maxValue
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.divider)
                            Capsule()
                                .fill(isMax ? theme.accentPrimary : theme.accentPrimary.opacity(0.35))
                                .frame(width: max(geo.size.width * values[i], values[i] > 0 ? 3 : 0))
                        }
                    }
                    .frame(height: 10)
                }
            }
            HStack {
                ForEach(0..<values.count, id: \.self) { i in
                    Text("\(labels[i]) \(Int(values[i] * 100))%")
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// 一周分布条：7 根竖条，高度按占比，最高日高亮
    private func weekdayBar(values: [Double], labels: [String]) -> some View {
        let maxValue = values.max() ?? 0
        let barHeight: CGFloat = 44
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<values.count, id: \.self) { i in
                let isMax = values[i] > 0 && values[i] >= maxValue
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(theme.divider).frame(height: barHeight)
                        Capsule()
                            .fill(isMax ? theme.accentPrimary : theme.accentPrimary.opacity(0.35))
                            .frame(height: max(3, barHeight * values[i]))
                    }
                    Text(labels[i])
                        .font(.caption2).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 内容排期详情


// MARK: - 评论管理详情

/// 单条评论数据
struct CommentItem: Identifiable, Sendable {
    let id: String
    let username: String
    let text: String
    let timestamp: Date
    let isReplied: Bool
}

struct CommentManagementDetailView: View {
    @Environment(\.theme) private var theme
    let comments: [CommentItem]

    private var pendingCount: Int { comments.filter { !$0.isReplied }.count }
    private var repliedCount: Int { comments.filter { $0.isReplied }.count }
    private var over24hCount: Int {
        comments.filter { !$0.isReplied && Date().timeIntervalSince($0.timestamp) > 86400 }.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            if comments.isEmpty {
                ContentUnavailableView(
                    loc(L10n.Premium.commentManagement),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(loc(L10n.Premium.commentMgmtDesc))
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // 统计徽章
                        HStack(spacing: 20) {
                            statBadge(count: "\(pendingCount)", label: loc(L10n.Premium.pending), color: theme.warningOrange)
                            statBadge(count: "\(over24hCount)", label: loc(L10n.Premium.over24h), color: theme.negativeRed)
                            statBadge(count: "\(repliedCount)", label: loc(L10n.Premium.replied), color: theme.positiveGreen)
                        }
                        .padding(.horizontal)

                        // 评论列表
                        ForEach(comments) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(item.isReplied ? theme.positiveGreen.opacity(0.2) : theme.accentPrimary.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(String(item.username.prefix(1).uppercased()))
                                            .font(.caption).fontWeight(.bold)
                                            .foregroundColor(item.isReplied ? theme.positiveGreen : theme.accentPrimary)
                                    }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("@\(item.username)").font(.subheadline).fontWeight(.semibold)
                                        Spacer()
                                        if item.isReplied {
                                            Label(loc(L10n.Premium.replied), systemImage: "checkmark.circle.fill")
                                                .font(.caption2).foregroundColor(theme.positiveGreen)
                                        } else {
                                            Text(timeAgo(from: item.timestamp))
                                                .font(.caption2)
                                                .foregroundColor(
                                                    Date().timeIntervalSince(item.timestamp) > 86400
                                                        ? theme.negativeRed : .secondary
                                                )
                                        }
                                    }
                                    Text(item.text).font(.subheadline).foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(theme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(loc(L10n.Premium.commentManagement))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBadge(count: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count).font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding().frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

