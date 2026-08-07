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
//  MARK: - DashboardView (Root)
//  （DashboardCard 已移至 Shared/DashboardCard.swift 供 Settings 共用）
// ═══════════════════════════════════════════════════════

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DashboardViewModel
    @Bindable var settingsViewModel: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var showProfileSheet = false

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
                        // 滚动内容（头像在导航栏 toolbar，与标题同一水平线）
                        ScrollView {
                            VStack(spacing: 12) {
                                // 多账户快速切换（仅 >1 个账号时显示，Menu 留在内容区不进工具栏）
                                if viewModel.accounts.count > 1 {
                                    HStack {
                                        Menu {
                                            ForEach(viewModel.accounts, id: \.id) { account in
                                                Button {
                                                    if let id = account.id { viewModel.selectAccount(id) }
                                                } label: {
                                                    HStack {
                                                        Text("@\(account.username)")
                                                        if account.id == viewModel.selectedAccountId {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label(
                                                viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountId })?.username ?? "",
                                                systemImage: "chevron.up.chevron.down"
                                            )
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                }

                                // 最近内容 — 上移至原折线图位置
                                RecentPostsSection(posts: viewModel.recentPosts)
                                // 指标卡片 — 互动率 / 帖子数（竖向堆叠，Liquid Glass）
                                KeyMetricsSection(
                                    snapshot: viewModel.latestSnapshot,
                                    engagementDelta: viewModel.engagementDelta,
                                    postsDelta: viewModel.postsDelta
                                )
                                PremiumInsightsSection(
                                    viewModel: viewModel
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                        .scrollContentBackground(.hidden)
                        // Scroll Edge Effect — 内容与导航栏 / TabBar 玻璃控件间的柔和过渡
                        .scrollEdgeEffectStyle(.soft, for: .top)
                        .scrollEdgeEffectStyle(.soft, for: .bottom)
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
            .navigationTitle(loc(L10n.Dashboard.title))
            .navigationBarTitleDisplayMode(.inline)
            // 头像按钮置于 toolbar trailing — 与「仪表盘」标题同一水平线
            // （纯简单视图：无 Spacer/Menu/sheet，避免 toolbar 布局 bug）
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountBar { showProfileSheet = true }
                        .frame(width: 32, height: 32)
                }
            }
            .refreshable { await viewModel.loadAccounts() }
        }
        // 个人资料弹窗由 Dashboard 根层级呈现（不挂 toolbar 内视图）
        .sheet(isPresented: $showProfileSheet) {
            AccountProfileSheet(
                accounts: viewModel.accounts,
                selectedAccountId: viewModel.selectedAccountId,
                settingsViewModel: settingsViewModel,
                onSelect: { id in viewModel.selectAccount(id) }
            )
            // sheet presentation root：显式同步系统模式（sheet 不继承父层 colorScheme）
            .preferredColorScheme(appState.currentTheme.theme.isDark ? .dark : .light)
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
//  指标卡片 — 互动率 / 帖子数两张卡片，竖向堆叠，Liquid Glass 背景。
//  每张卡片含主指标 + 3 个附加指标。
// ═══════════════════════════════════════════════════════

private struct KeyMetricsSection: View {
    let snapshot: Snapshot?
    let engagementDelta: Double
    let postsDelta: Int

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            engagementCard
            postsCard
        }
    }

    // MARK: 互动率卡片

    /// 互动率卡片 — 互动率(主) + 总赞 + 总评论 + 总分享
    private var engagementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(loc(L10n.Dashboard.engagementRate), systemImage: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(deltaText(engagementDelta, unit: "%", isPercent: true))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(engagementDelta >= 0 ? theme.accentPrimary : theme.negativeRed)
            }
            .padding(.bottom, 2)

            Text(String(format: "%.1f%%", snapshot?.engagementRate ?? 0))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 0) {
                miniMetric(icon: "hand.thumbsup.fill",
                           label: loc(L10n.Dashboard.likes),
                           value: formatCompact(snapshot?.totalLikes ?? 0))
                Divider().padding(.vertical, 6)
                miniMetric(icon: "bubble.left.fill",
                           label: loc(L10n.Dashboard.comments),
                           value: formatCompact(snapshot?.totalComments ?? 0))
                Divider().padding(.vertical, 6)
                miniMetric(icon: "arrowshape.turn.up.right.fill",
                           label: loc(L10n.Dashboard.shares),
                           value: formatCompact(snapshot?.totalShares ?? 0))
            }
        }
        .padding(16)
        .dashboardCard()
    }

    // MARK: 帖子数卡片

    /// 帖子数卡片 — 帖子数(主) + 总曝光 + 平均赞/帖 + 平均评论/帖
    private var postsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(loc(L10n.Dashboard.posts), systemImage: "doc.text.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(deltaText(Double(postsDelta), unit: "", isPercent: false))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(postsDelta >= 0 ? theme.accentPrimary : theme.negativeRed)
            }
            .padding(.bottom, 2)

            Text("\(snapshot?.mediaCount ?? 0)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 0) {
                miniMetric(icon: "eye.fill",
                           label: loc(L10n.Dashboard.views),
                           value: formatCompact(snapshot?.totalViews ?? 0))
                Divider().padding(.vertical, 6)
                miniMetric(icon: "heart.circle.fill",
                           label: loc(L10n.Dashboard.avgLikes),
                           value: formatCompact(avgLikes))
                Divider().padding(.vertical, 6)
                miniMetric(icon: "bubble.left.and.bubble.right.fill",
                           label: loc(L10n.Dashboard.avgComments),
                           value: formatCompact(avgComments))
            }
        }
        .padding(16)
        .dashboardCard()
    }

    /// 平均赞/帖（媒体数为 0 时返回 0）
    private var avgLikes: Int {
        guard let s = snapshot, s.mediaCount > 0 else { return 0 }
        return s.totalLikes / s.mediaCount
    }

    /// 平均评论/帖（媒体数为 0 时返回 0）
    private var avgComments: Int {
        guard let s = snapshot, s.mediaCount > 0 else { return 0 }
        return s.totalComments / s.mediaCount
    }

    /// 小指标列：图标 + 标签 + 数值
    private func miniMetric(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(theme.accentPrimary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
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
            // ── 标题行（整行可点 → All Posts 列表页；无数据时也可进入）──
            NavigationLink {
                PostListView(posts: posts)
            } label: {
                HStack(spacing: 6) {
                    Text(loc(L10n.Dashboard.recentContent))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                    Spacer()
                    Text(loc(L10n.Dashboard.viewAll))
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    private var isUnlocked: Bool {
        appState.premiumEnabledFlags[PremiumFeatureKey.trendPrediction.rawValue] == true
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

    // MARK: - Body（Glass.swift 滚动式：连续双列网格，无分页）

    var body: some View {
        VStack(spacing: 12) {
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

            // ── 连续双列 Liquid Glass 网格（随页面滚动，无分页）──
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(allPremiumItems.enumerated()), id: \.offset) { index, item in
                    tileCard(item: item, globalIndex: index)
                }
            }
            .padding(.horizontal, 16)
        }
        .premiumGate(feature: .trendPrediction)
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
            // 统一居中布局：图标居中，文字与图标对齐（水平居中）
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(theme.accentPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 110)
            .followerGlassEffect(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }

    /// 锁定态 Tile
    private func lockedTile(icon: String, label: String) -> some View {
        // 统一居中布局：图标居中（与解锁态一致），lock 徽章覆盖右上角
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.textTertiary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("—")
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
                .padding(8)
        }
        .followerGlassEffect(cornerRadius: 12)
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
    let settingsViewModel = SettingsViewModel(
        trialManager: container.trialManager,
        exportService: container.exportService,
        accountRepo: container.accountRepository,
        premiumFeatureRepo: container.premiumFeatureRepository
    )
    DashboardView(viewModel: viewModel, settingsViewModel: settingsViewModel)
        .environment(appState)
}
