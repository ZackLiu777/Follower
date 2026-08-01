//
//  DashboardView.swift
//  Follower
//
//  v4 — 仪表盘重构:
//      浅灰背景 + 白色卡片 + 蓝色强调
//      Profile Header → TrendChart 粉丝周线（与 Trends 页共用组件+数据源） →
//      Key Metrics Card → Recent Posts Card → Premium Grid Card
//

import SwiftUI

// ═══════════════════════════════════════════════════════
//  MARK: - DashboardCard Modifier
//  白色圆角卡片 + 细微阴影（匹配参考图）
// ═══════════════════════════════════════════════════════

private struct DashboardCard: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    func body(content: Content) -> some View {
        if useLiquidGlass {
            // Liquid Glass 模式: Material 毛玻璃 + theme.cardSurface 半透明色叠层
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                        RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(theme.isDark ? 0.10 : 0.05), radius: 8, y: 2)
        } else {
            // 非 Liquid Glass (如 Mono Stone): 直接用 cardSurface
            content
                .background(theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
}

extension View {
    fileprivate func dashboardCard() -> some View { modifier(DashboardCard()) }
}

// ═══════════════════════════════════════════════════════
//  MARK: - DashboardView (Root)
// ═══════════════════════════════════════════════════════

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = updateSyncState()

        NavigationStack {
            Group {
                if viewModel.accounts.isEmpty {
                    emptyOrErrorView
                } else if let error = viewModel.errorMessage {
                    errorView(error: error)
                } else if viewModel.latestSnapshot != nil {
                    ZStack {
                        LinearGradient(
                            colors: theme.backgroundGradientColors,
                            startPoint: .top, endPoint: .bottom
                        ).ignoresSafeArea()
                        ScrollView {
                            VStack(spacing: 12) {
                                AccountBar(
                                    accounts: viewModel.accounts,
                                    selectedAccountId: viewModel.selectedAccountId,
                                    onSelect: { id in viewModel.selectAccount(id) }
                                )
                                // 粉丝周线统计图表 — 与 Trends 页共用同一 TrendChart 组件 + 同一数据源
                                NavigationLink {
                                    TrendDetailView(
                                        metricType: .followerGrowth,
                                        dataPoints: viewModel.followerWeeklyData,
                                        timeWindow: .week,
                                        barGradientStart: theme.chartBarGradientStart,
                                        barGradientEnd: theme.chartBarGradientEnd
                                    )
                                } label: {
                                    TrendChart(
                                        dataPoints: viewModel.followerWeeklyData,
                                        barGradientStart: theme.chartBarGradientStart,
                                        barGradientEnd: theme.chartBarGradientEnd,
                                        title: loc(L10n.Trends.followers),
                                        timeWindow: .week,
                                        compact: true
                                    )
                                    .dashboardCard()
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 4)
                                KeyMetricsSection(
                                    engagementRate: viewModel.latestSnapshot?.engagementRate ?? 0,
                                    reach: viewModel.latestSnapshot?.totalViews ?? 0,
                                    posts: viewModel.latestSnapshot?.mediaCount ?? 0,
                                    engagementDelta: viewModel.engagementDelta,
                                    reachDelta: viewModel.reachDelta,
                                    postsDelta: viewModel.postsDelta
                                )
                                RecentPostsSection(posts: viewModel.recentPosts)
                                PremiumInsightsSection(
                                    viewModel: viewModel
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else if viewModel.isLoading || viewModel.isSyncing {
                    ZStack {
                        LinearGradient(
                            colors: theme.backgroundGradientColors,
                            startPoint: .top, endPoint: .bottom
                        ).ignoresSafeArea()
                        ProgressView(loc(L10n.Common.loading))
                            .frame(maxWidth: .infinity, minHeight: 300)
                    }
                } else {
                    ZStack {
                        LinearGradient(
                            colors: theme.backgroundGradientColors,
                            startPoint: .top, endPoint: .bottom
                        ).ignoresSafeArea()
                        EmptyStateView(
                            icon: "arrow.triangle.2.circlepath",
                            title: loc(L10n.Dashboard.noDataTitle),
                            message: loc(L10n.Dashboard.noDataMessage),
                            actionLabel: loc(L10n.Common.syncNow),
                            action: { Task { await viewModel.sync() } }
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.loadAccounts() }
        }
        .task { await viewModel.loadAccounts() }
        .onChange(of: viewModel.selectedAccountId) { _, newId in
            appState.selectedAccountId = newId
        }
    }

    // MARK: - Helpers

    private var emptyOrErrorView: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            EmptyStateView(
                icon: "person.crop.circle.badge.exclamationmark",
                title: loc(L10n.Dashboard.noAccountTitle),
                message: loc(L10n.Dashboard.noAccountMessage),
                actionLabel: loc(L10n.Dashboard.connectAccount),
                action: {}
            )
        }
    }

    private func errorView(error: String) -> some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    ErrorBanner(
                        message: error,
                        onDismiss: { viewModel.errorMessage = nil },
                        onRetry: { Task { await viewModel.loadAccounts() } }
                    )
                }
                .padding(.horizontal, 16)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func updateSyncState() {
        if viewModel.accounts.isEmpty {
            appState.syncState = .noAccount
        } else if viewModel.latestSnapshot != nil {
            appState.syncState = .dataReady
        } else if viewModel.isLoading || viewModel.isSyncing {
            appState.syncState = .syncing
        } else {
            appState.syncState = .readyToSync
        }
    }

}

// ═══════════════════════════════════════════════════════
//  MARK: - 2. KeyMetricsSection
//  参考图: 白色卡片 — 3 列指标（互动率 / 覆盖人数 / 帖子数）
//  每列: 图标 + 标签 + 大数字 + delta
// ═══════════════════════════════════════════════════════

private struct KeyMetricsSection: View {
    let engagementRate: Double
    let reach: Int
    let posts: Int
    let engagementDelta: Double
    let reachDelta: Int
    let postsDelta: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            metricColumn(
                icon: "heart.fill",
                label: loc(L10n.Dashboard.engagementRate),
                value: String(format: "%.1f%%", engagementRate),
                deltaText: deltaText(engagementDelta, unit: "%", isPercent: true),
                isPositive: engagementDelta >= 0
            )

            Divider().padding(.vertical, 8)

            metricColumn(
                icon: "eye.fill",
                label: loc(L10n.Dashboard.reach),
                value: formatCompact(reach),
                deltaText: deltaText(Double(reachDelta), unit: "", isPercent: false),
                isPositive: reachDelta >= 0
            )

            Divider().padding(.vertical, 8)

            metricColumn(
                icon: "doc.text.fill",
                label: loc(L10n.Dashboard.posts),
                value: "\(posts)",
                deltaText: deltaText(Double(postsDelta), unit: "", isPercent: false),
                isPositive: postsDelta >= 0
            )
        }
        .padding(16)
        .dashboardCard()
    }

    private func metricColumn(icon: String, label: String, value: String, deltaText: String, isPositive: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(theme.accentPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Text(deltaText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isPositive ? theme.accentPrimary : theme.negativeRed)
        }
        .frame(maxWidth: .infinity)
    }

    private func deltaText(_ val: Double, unit: String, isPercent: Bool) -> String {
        let prefix = val >= 0 ? "↑ " : "↓ "
        if isPercent {
            return "\(prefix)\(String(format: "%+.1f", val))\(unit)"
        }
        return "\(prefix)\(formatCompact(Int(val)))"
    }

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 3. RecentPostsSection
//  参考图: 白色卡片 — "最近帖子" + "查看全部" + 帖子行列表
//  每行: 缩略图(60x60) + 标题 + 日期 + 互动数据
// ═══════════════════════════════════════════════════════

private struct RecentPostsSection: View {
    let posts: [MediaPost]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // ── 标题行 ──
            HStack {
                Text(loc(L10n.Dashboard.recentContent))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if !posts.isEmpty {
                    NavigationLink(loc(L10n.Dashboard.viewAll)) {
                        PostListView(posts: posts)
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if posts.isEmpty {
                Text(loc(L10n.Dashboard.noPostsHint))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                // ── 帖子行 ──
                VStack(spacing: 0) {
                    ForEach(posts) { post in
                        NavigationLink {
                            PostDetailView(post: post)
                        } label: {
                            PostRowView(post: post)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if post.id != posts.last?.id {
                            Divider()
                                .padding(.leading, 76) // 对齐缩略图右侧
                        }
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// ═══════════════════════════════════════════════════════
//  MARK: - 4. PremiumInsightsSection
//  2×2 网格分页滚动 + 底部小点指示器
//  全部 9 项 Premium 入口，每页 4 格，共 3 页
// ═══════════════════════════════════════════════════════

private struct PremiumInsightsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @Environment(\.useLiquidGlass) private var useLiquidGlass

    let viewModel: DashboardViewModel

    @State private var currentPage: Int = 0

    private var isUnlocked: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.trendPrediction.rawValue] == true
    }

    /// 每页 4 格
    private let itemsPerPage = 4
    /// 总页数
    private var totalPages: Int {
        let all = allPremiumItems
        return (all.count + itemsPerPage - 1) / itemsPerPage
    }

    // MARK: - 数据源: 全部 9 项

    private var allPremiumItems: [PremiumTileItem] {
        if isUnlocked {
            return [
                .init(icon: "chart.line.uptrend.xyaxis.circle", label: loc(L10n.Premium.followerPrediction),
                      value: viewModel.predictionResult.map {
                          "~\(Int($0.predictedValue).formatted(.number)) \(loc(L10n.Premium.in30Days))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis),
                      value: viewModel.activityResult.map {
                          "\($0.label) · \($0.activeDays)/\($0.totalDays) \(loc(L10n.Premium.daysActive))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality),
                      value: viewModel.qualityScore.map {
                          "Score: \(String(format: "%.1f", $0.score)) — \($0.label)"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn),
                      value: viewModel.retentionResult.map {
                          "Growth: \(String(format: "%+.1f%%", $0.netGrowthRate)) · Risk: \($0.churnRiskLevel)"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "globe.asia.australia.fill", label: loc(L10n.Premium.geoDistribution),
                      value: viewModel.geoDistribution.map {
                          "\($0.regions.prefix(2).map(\.name).joined(separator: ", "))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison),
                      value: viewModel.comparisonResult.map {
                          "\($0.direction.rawValue) · \(String(format: "%+.2f", $0.absoluteChange))"
                      } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou),
                      value: "\(viewModel.unfollowList.count) \(loc(L10n.Premium.peopleThisWeek))", locked: false),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost),
                      value: viewModel.activityResult?.mostActiveDay != nil
                          ? "\(loc(L10n.Premium.mostActiveDay)) \(viewModel.activityResult!.mostActiveDay!)"
                          : viewModel.bestPostingTime, locked: false),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy),
                      value: viewModel.aiSummary.isEmpty ? viewModel.contentTip : viewModel.aiSummary, locked: false),
                // Phi: 三大人群画像 Premium 功能
                .init(icon: "chart.bar.fill", label: loc(L10n.Premium.competitorComparison),
                      value: viewModel.comparisonResult.map { "\($0.direction.rawValue) · \(String(format: "%+.0f", $0.absoluteChange))" } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "checkmark.shield.fill", label: loc(L10n.Premium.authenticityAssessment),
                      value: viewModel.authenticityResult.map { "Score: \(Int($0.score))/100 · \($0.growthPattern)" } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "doc.richtext.fill", label: loc(L10n.Premium.mediaKitExport),
                      value: "3 templates · PDF export", locked: false),
                .init(icon: "chart.line.flattrend.xyaxis", label: loc(L10n.Premium.campaignTracking),
                      value: viewModel.campaignResult.map { String(format: "%+.1f%% growth", $0.followerGrowthRate) } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "square.grid.3x3.fill", label: loc(L10n.Premium.engagementHeatmap),
                      value: viewModel.heatmapResult.map { "Peak: \($0.peakDescription)" } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "calendar.badge.plus", label: loc(L10n.Premium.contentScheduling),
                      value: viewModel.activityResult.map { "\($0.activeDays)/\($0.totalDays) \(loc(L10n.Premium.daysActive))" } ?? loc(L10n.Premium.analyzing), locked: false),
                .init(icon: "bubble.left.and.bubble.right.fill", label: loc(L10n.Premium.commentManagement),
                      value: "4 pending · 2 overdue", locked: false),
            ]
        } else {
            return [
                .init(icon: "chart.line.uptrend.xy", label: loc(L10n.Premium.followerPrediction), value: "", locked: true),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis), value: "", locked: true),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality), value: "", locked: true),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn), value: "", locked: true),
                .init(icon: "globe.asia.australia.fill", label: loc(L10n.Premium.geoDistribution), value: "", locked: true),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison), value: "", locked: true),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou), value: "", locked: true),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost), value: "", locked: true),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy), value: "", locked: true),
                // Phi: 三大人群画像 Premium 功能
                .init(icon: "chart.bar.fill", label: loc(L10n.Premium.competitorComparison), value: "", locked: true),
                .init(icon: "checkmark.shield.fill", label: loc(L10n.Premium.authenticityAssessment), value: "", locked: true),
                .init(icon: "doc.richtext.fill", label: loc(L10n.Premium.mediaKitExport), value: "", locked: true),
                .init(icon: "chart.line.flattrend.xyaxis", label: loc(L10n.Premium.campaignTracking), value: "", locked: true),
                .init(icon: "square.grid.3x3.fill", label: loc(L10n.Premium.engagementHeatmap), value: "", locked: true),
                .init(icon: "calendar.badge.plus", label: loc(L10n.Premium.contentScheduling), value: "", locked: true),
                .init(icon: "bubble.left.and.bubble.right.fill", label: loc(L10n.Premium.commentManagement), value: "", locked: true),
            ]
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            // ── 标题行 ──
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                Text(loc(L10n.Premium.premiumInsights))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundColor(theme.accentPrimary)
            .padding(.horizontal, 16)

            // ── 分页 2×2 网格 ──
            TabView(selection: $currentPage) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    let items = Array(allPremiumItems[itemsPerPage * pageIndex..<min(itemsPerPage * (pageIndex + 1), allPremiumItems.count)])
                    gridPage(items: items, pageIndex: pageIndex)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: gridHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // ── 页面指示器小点 ──
            if totalPages > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage
                                  ? theme.accentPrimary
                                  : theme.textTertiary.opacity(0.35))
                            .frame(width: index == currentPage ? 7 : 5,
                                   height: index == currentPage ? 7 : 5)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 2)
            }
        }
        .premiumGate(feature: .trendPrediction)
    }

    // MARK: - 2×2 Grid Page

    private func gridPage(items: [PremiumTileItem], pageIndex: Int) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { localIndex, item in
                    tileCard(item: item, globalIndex: itemsPerPage * pageIndex + localIndex)
                }

                // 最后一页不足 4 格时，用占位补齐保持 2×2
                if items.count < itemsPerPage {
                    ForEach(items.count..<itemsPerPage, id: \.self) { _ in
                        Color.clear
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - 单个 Tile 卡片

    private func tileCard(item: PremiumTileItem, globalIndex: Int) -> some View {
        Group {
            if item.locked {
                lockedTile(icon: item.icon, label: item.label)
            } else {
                unlockedTile(icon: item.icon, label: item.label, value: item.value, globalIndex: globalIndex)
            }
        }
    }

    /// 解锁态 Tile
    @ViewBuilder
    private func unlockedTile(icon: String, label: String, value: String, globalIndex: Int) -> some View {
        let destination = destinationFor(index: globalIndex)
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(theme.accentPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// 锁定态 Tile
    private func lockedTile(icon: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("—")
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary.opacity(0.5))

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 根据全局 index 返回对应跳转页面
    @ViewBuilder
    private func destinationFor(index: Int) -> some View {
        switch index {
        case 0: PredictionDetailView(predicted: viewModel.predictedFollowers, historical: viewModel.sparklineData)
        case 1: ActivityDetailView(result: viewModel.activityResult)
        case 2: QualityDetailView(result: viewModel.qualityScore)
        case 3: RetentionDetailView(result: viewModel.retentionResult)
        case 4: GeoDetailView(result: viewModel.geoDistribution)
        case 5: ComparisonDetailView(result: viewModel.comparisonResult)
        case 6: UnfollowListView(followers: viewModel.unfollowList)
        case 7: BestTimeView(heatmapResult: viewModel.heatmapResult)
        case 8: ContentStrategyView(aiSummary: viewModel.aiSummary.isEmpty ? viewModel.contentTip : viewModel.aiSummary)
        // Phi: 三大人群画像新 Premium 功能
        case 9: CompetitorDetailView(comparisonResult: viewModel.comparisonResult)
        case 10: AuthenticityDetailView(result: viewModel.authenticityResult)
        case 11: MediaKitDetailView()
        case 12: CampaignDetailView(result: viewModel.campaignResult)
        case 13: HeatmapDetailView(result: viewModel.heatmapResult)
        case 14: ContentSchedulingDetailView(activityResult: viewModel.activityResult)
        case 15: CommentManagementDetailView(comments: [])
        default: EmptyView()
        }
    }

    /// 2×2 网格高度: padding(12) * 2 + tile(110) * 2 + spacing(10)
    private var gridHeight: CGFloat { 264 }

    /// 卡片背景: Liquid Glass / 不透明
    @ViewBuilder
    private var cardBackground: some View {
        if useLiquidGlass {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16).fill(theme.cardSurface)
            }
        } else {
            theme.cardSurface
        }
    }
}

/// Premium Tile 数据模型
private struct PremiumTileItem {
    let icon: String
    let label: String
    let value: String
    let locked: Bool
}

// ═══════════════════════════════════════════════════════
//  MARK: - Preview
// ═══════════════════════════════════════════════════════

#Preview {
    let appState = AppState(databaseManager: DatabaseManager.shared)
    let container = appState.container
    let viewModel = DashboardViewModel(
        snapshotRepo: container.snapshotRepository,
        metricRepo: container.metricRepository,
        accountRepo: container.accountRepository,
        syncEngine: container.syncEngine,
        eventRepo: container.eventRepository,
        predictionService: container.predictionService,
        activityService: container.activityAnalysisService,
        retentionService: container.retentionAnalysisService,
        scoringService: container.scoringService,
        geoService: container.geoDistributionService,
        comparisonService: container.comparisonService,
        aiService: container.aiAnalysisService,
        authenticityService: container.authenticityService,
        campaignComparisonService: container.campaignComparisonService,
        engagementHeatmapService: container.engagementHeatmapService
    )
    DashboardView(viewModel: viewModel)
        .environment(appState)
}
