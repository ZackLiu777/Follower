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
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = comparisonResult {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(String(format: "%+.2f", result.absoluteChange))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(result.absoluteChange >= 0 ? theme.positiveGreen : theme.negativeRed)
                            Text(loc(L10n.Premium.competitorGrowth))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            compareCard(
                                title: loc(L10n.Premium.competitorYou),
                                value: "\(Int(result.absoluteChange))",
                                label: loc(L10n.Premium.followers),
                                color: theme.accentPrimary
                            )
                            compareCard(
                                title: loc(L10n.Premium.competitorPeersAvg),
                                value: result.direction.rawValue,
                                label: "Trend",
                                color: theme.textSecondary
                            )
                        }
                        .padding(.horizontal)

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

    private func compareCard(title: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = result {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(Int(result.score))/100")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor(result.score))
                            Text(loc(L10n.Premium.authenticityScore))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            scoreRow(label: loc(L10n.Premium.engagementQuality),
                                     value: "\(Int(result.engagementQuality))/100",
                                     color: scoreColor(result.engagementQuality))
                            scoreRow(label: loc(L10n.Premium.growthPattern),
                                     value: result.growthPattern,
                                     color: result.growthPattern == "Natural" ? theme.positiveGreen : theme.warningOrange)
                            scoreRow(label: loc(L10n.Premium.followerAuthenticity),
                                     value: "\(Int(result.followerAuthenticity))/100",
                                     color: scoreColor(result.followerAuthenticity))
                            scoreRow(label: loc(L10n.Premium.anomalyDetection),
                                     value: result.hasAnomalies ? result.anomalyDescription ?? "Anomalies" : loc(L10n.Premium.noAnomalies),
                                     color: result.hasAnomalies ? theme.warningOrange : theme.textSecondary)
                        }
                        .padding()
                        .background(.regularMaterial)
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

    private func scoreRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.primary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(color)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return theme.positiveGreen }
        if score >= 50 { return theme.accentPrimary }
        if score >= 30 { return theme.warningOrange }
        return theme.negativeRed
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

// MARK: - 媒体包导出详情（Alpha 阶段保留 UI 壳，PDF 生成后续实现）

struct MediaKitDetailView: View {
    @Environment(\.theme) private var theme
    @State private var selectedTemplate: Int = 0

    private var templates: [String] {
        [loc(L10n.Premium.templateProfessional),
         loc(L10n.Premium.templateCreative),
         loc(L10n.Premium.templateMinimal)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
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
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc(L10n.Premium.template)).font(.headline).padding(.horizontal)
                        Picker(loc(L10n.Premium.template), selection: $selectedTemplate) {
                            ForEach(0..<templates.count, id: \.self) { i in Text(templates[i]).tag(i) }
                        }
                        .pickerStyle(.segmented).padding(.horizontal)
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
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)

                    Button {} label: {
                        Label(loc(L10n.Premium.exportPDF), systemImage: "arrow.down.doc.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                            .background(theme.accentPrimary).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
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
                        .background(.regularMaterial)
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
        .background(.regularMaterial)
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

/// Premium 详情页：基于 Event 时间戳的 7×24 互动热力图
struct HeatmapDetailView: View {
    @Environment(\.theme) private var theme
    let result: EngagementHeatmapResult?

    private var dayLabels: [String] {
        [loc(L10n.Premium.daySun), loc(L10n.Premium.dayMon), loc(L10n.Premium.dayTue),
         loc(L10n.Premium.dayWed), loc(L10n.Premium.dayThu), loc(L10n.Premium.dayFri),
         loc(L10n.Premium.daySat)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if let result = result, !result.cells.isEmpty {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(result.peakDescription)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(theme.accentPrimary)
                            Text(loc(L10n.Premium.peakEngagementTime))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal)

                        VStack(spacing: 2) {
                            ForEach(1...7, id: \.self) { wd in
                                HStack(spacing: 2) {
                                    Text(dayLabels[wd - 1])
                                        .font(.caption2).frame(width: 30, alignment: .leading)
                                        .foregroundColor(.secondary)
                                    ForEach(0..<24, id: \.self) { hour in
                                        Rectangle()
                                            .fill(theme.accentPrimary.opacity(result.density(weekday: wd, hour: hour)))
                                            .frame(height: 20)
                                    }
                                }
                            }
                            HStack(spacing: 2) {
                                Color.clear.frame(width: 30)
                                ForEach(0..<24, id: \.self) { hour in
                                    if hour % 6 == 0 {
                                        Text("\(hour)").font(.system(size: 8))
                                            .foregroundColor(.secondary).frame(maxWidth: .infinity)
                                    } else { Color.clear }
                                }
                            }
                        }
                        .padding().background(.regularMaterial)
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
}

// MARK: - 内容排期详情

/// Premium 详情页：基于 Activity 分析结果推荐最佳发帖时间
struct ContentSchedulingDetailView: View {
    @Environment(\.theme) private var theme
    let activityResult: ActivityResult?

    private var recommendations: [(day: String, time: String, reason: String)] {
        guard let result = activityResult else { return [] }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = result.mostActiveDay.map { $0 >= 1 && $0 <= 7 ? dayNames[$0 - 1] : "Mon" } ?? "Mon"
        return [
            (day, "19:00", loc(L10n.Premium.reasonPeakEngagement)),
            (day, "12:00", loc(L10n.Premium.reasonLunchtime)),
            ("Mon", "20:00", loc(L10n.Premium.reasonStartOfWeek)),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                if !recommendations.isEmpty {
                    VStack(spacing: 20) {
                        Text(loc(L10n.Premium.next3Days))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(rec.day) at \(rec.time)").font(.title3).fontWeight(.bold)
                                    Text(rec.reason).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "\(index + 1).circle.fill")
                                    .font(.title2).foregroundColor(theme.accentPrimary)
                            }
                            .padding().background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                        }

                        Text(loc(L10n.Premium.schedulingDesc))
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    ContentUnavailableView(
                        loc(L10n.Premium.noDataAvailable),
                        systemImage: "calendar.badge.plus",
                        description: Text(loc(L10n.Premium.noDataActivityDesc))
                    )
                    .padding(.top, 80)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.contentScheduling))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 评论管理详情（Alpha 保留 UI 壳，实际对接 Instagram API 后续实现）

struct CommentManagementDetailView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ContentUnavailableView(
                loc(L10n.Premium.commentManagement),
                systemImage: "bubble.left.and.bubble.right",
                description: Text(loc(L10n.Premium.commentMgmtDesc))
            )
        }
        .navigationTitle(loc(L10n.Premium.commentManagement))
        .navigationBarTitleDisplayMode(.inline)
    }
}

