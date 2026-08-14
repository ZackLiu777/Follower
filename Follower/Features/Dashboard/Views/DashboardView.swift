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
    @State private var showSettingsSheet = false

    var body: some View {
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
                            // LazyVStack：3 个 Section 离屏即释放，避免 19 张卡片常驻渲染树
                            LazyVStack(spacing: 12) {
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
                                // 指标卡片 — 帖子数（Liquid Glass）
                                // v0.11：互动率卡片已删除（互动率指标从 UI 移除，数据生成保留）
                                KeyMetricsSection(
                                    snapshot: viewModel.latestSnapshot,
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
            // 设置按钮置于 toolbar trailing — 与「仪表盘」标题同一水平线
            // （纯简单视图：无 Spacer/Menu/sheet，避免 toolbar 布局 bug）
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettingsSheet = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("dashboard_settings_button")
                }
            }
            // 下拉刷新 = 增量同步（60 秒节流防 Instagram 配额耗尽）；
            // 账号列表由 .task 与 accountCreated 通知维护，不在此刷新
            .refreshable { await viewModel.incrementalSync() }
        }
        // 设置页由 Dashboard 根层级呈现（不挂 toolbar 内视图）
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            // sheet presentation root：显式同步系统模式（sheet 不继承父层 colorScheme）
            .preferredColorScheme(appState.currentTheme.theme.isDark ? .dark : .light)
        }
        .task { await viewModel.loadAccounts() }
        .onChange(of: viewModel.selectedAccountId) { _, newId in
            appState.selectedAccountId = newId
        }
        // Profile tab 切换账号（直接写 appState.selectedAccountId）→ 仪表盘数据联动刷新。
        // 幂等保护：Dashboard 自身切换时 VM 已同步，newId == viewModel.selectedAccountId 跳过
        .onChange(of: appState.selectedAccountId) { _, newId in
            if let newId, newId != viewModel.selectedAccountId {
                viewModel.selectAccount(newId)
            }
        }
        // syncState 由状态变化驱动（替代原 body 内无条件写入 — @Observable setter 无值比较，
        // 每次 body 求值都写会通知订阅者引起无谓重绘链）；值保护：相同状态不写
        .onChange(of: viewModel.accounts.count) { _, _ in updateSyncState() }
        .onChange(of: viewModel.selectedAccountId) { _, _ in updateSyncState() }
        .onChange(of: viewModel.latestSnapshot?.id) { _, _ in updateSyncState() }
        .onChange(of: viewModel.isLoading) { _, _ in updateSyncState() }
        .onChange(of: viewModel.isSyncing) { _, _ in updateSyncState() }
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

    /// 同步状态由 onChange 驱动；仅状态实际变化时才写（@Observable setter 无值比较，
    /// 相同值写入仍通知订阅者 → 无谓重绘链）
    private func updateSyncState() {
        let newState: AppSyncState
        if viewModel.accounts.isEmpty {
            newState = .noAccount
        } else if viewModel.latestSnapshot != nil {
            newState = .dataReady
        } else if viewModel.isLoading || viewModel.isSyncing {
            newState = .syncing
        } else {
            newState = .readyToSync
        }
        if appState.syncState != newState {
            appState.syncState = newState
        }
    }

}

// ═══════════════════════════════════════════════════════
//  MARK: - 2. KeyMetricsSection
//  指标卡片 — 帖子数卡片，Liquid Glass 背景。
//  v0.11：互动率卡片已删除（互动率指标从 UI 移除，数据生成保留）。
// ═══════════════════════════════════════════════════════

private struct KeyMetricsSection: View {
    let snapshot: Snapshot?
    let postsDelta: Int

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            postsCard
        }
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
                Text(deltaText(Double(postsDelta)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(postsDelta >= 0 ? theme.accentPrimary : theme.negativeRed)
            }
            .padding(.bottom, 2)

            Text("\(snapshot?.mediaCount ?? 0)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 0) {
                // v0.14：总曝光（totalViews）已移除 — Instagram API 无可用浏览指标数据源，恒 0
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
        // fill：主题 postsCardBackground（品牌色低透明档，同 Recent Content 档位）
        .dashboardCard(fill: theme.postsCardBackground)
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

    /// 增减徽章文本（↑/↓ + 紧凑数值）；v0.11：百分比分支随互动率卡片一并移除
    private func deltaText(_ val: Double) -> String {
        let prefix = val >= 0 ? "↑ " : "↓ "
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
        // fill：主题 recentContentCardBackground（品牌色低透明档）
        .dashboardCard(fill: theme.recentContentCardBackground)
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

    // MARK: - 数据源: 全部 14 项（地域分布 / 评论管理已移除）

    private var allPremiumItems: [PremiumTileItem] {
        if isUnlocked {
            return [
                .init(icon: "chart.line.uptrend.xyaxis.circle", label: loc(L10n.Premium.followerPrediction), locked: false),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis), locked: false),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality), locked: false),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn), locked: false),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison), locked: false),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou), locked: false),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost), locked: false),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy), locked: false),
                // Phi: 三大人群画像 Premium 功能
                .init(icon: "chart.bar.fill", label: loc(L10n.Premium.competitorComparison), locked: false),
                .init(icon: "checkmark.shield.fill", label: loc(L10n.Premium.authenticityAssessment), locked: false),
                .init(icon: "doc.richtext.fill", label: loc(L10n.Premium.mediaKitExport), locked: false),
                .init(icon: "chart.line.flattrend.xyaxis", label: loc(L10n.Premium.campaignTracking), locked: false),
                .init(icon: "square.grid.3x3.fill", label: loc(L10n.Premium.engagementHeatmap), locked: false),
                .init(icon: "calendar.badge.plus", label: loc(L10n.Premium.contentScheduling), locked: false),
            ]
        } else {
            return [
                .init(icon: "chart.line.uptrend.xyaxis", label: loc(L10n.Premium.followerPrediction), locked: true),
                .init(icon: "bolt.fill", label: loc(L10n.Premium.activityAnalysis), locked: true),
                .init(icon: "star.fill", label: loc(L10n.Premium.engagementQuality), locked: true),
                .init(icon: "person.2.fill", label: loc(L10n.Premium.retentionChurn), locked: true),
                .init(icon: "arrow.left.arrow.right", label: loc(L10n.Premium.longTermComparison), locked: true),
                .init(icon: "person.2.slash", label: loc(L10n.Premium.whoUnfollowedYou), locked: true),
                .init(icon: "clock.fill", label: loc(L10n.Premium.bestTimeToPost), locked: true),
                .init(icon: "lightbulb.fill", label: loc(L10n.Premium.contentStrategy), locked: true),
                // Phi: 三大人群画像 Premium 功能
                .init(icon: "chart.bar.fill", label: loc(L10n.Premium.competitorComparison), locked: true),
                .init(icon: "checkmark.shield.fill", label: loc(L10n.Premium.authenticityAssessment), locked: true),
                .init(icon: "doc.richtext.fill", label: loc(L10n.Premium.mediaKitExport), locked: true),
                .init(icon: "chart.line.flattrend.xyaxis", label: loc(L10n.Premium.campaignTracking), locked: true),
                .init(icon: "square.grid.3x3.fill", label: loc(L10n.Premium.engagementHeatmap), locked: true),
                .init(icon: "calendar.badge.plus", label: loc(L10n.Premium.contentScheduling), locked: true),
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
                unlockedTile(icon: item.icon, label: item.label, globalIndex: globalIndex)
            }
        }
    }

    /// 解锁态 Tile
    @ViewBuilder
    private func unlockedTile(icon: String, label: String, globalIndex: Int) -> some View {
        let destination = destinationFor(index: globalIndex)
        NavigationLink(destination: destination) {
            // 统一居中布局：图标与标题在卡片内水平 + 垂直居中（上下 Spacer 均分留白）
            VStack(spacing: 8) {
                Spacer(minLength: 0)
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

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 110)
            // 静态填充版 glass：tile 是滚动路径数量最多的卡片（16 张），
            // material 每帧重采样是深色模式掉帧主因 — 用静态半透明填充替代
            // fill：主题 premiumCardBackground（品牌色半透明）
            .followerGlassEffect(cornerRadius: 12, usesMaterial: false, fill: theme.premiumCardBackground)
        }
        .buttonStyle(.plain)
    }

    /// 锁定态 Tile
    private func lockedTile(icon: String, label: String) -> some View {
        // 统一居中布局：图标与标题水平 + 垂直居中（与解锁态一致），lock 徽章覆盖右上角
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.textTertiary)
                .frame(width: 32, height: 32)
                .background(theme.textTertiary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

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
        // 静态填充版 glass（同 unlockedTile — 滚动路径性能）
        // fill：主题 premiumCardBackground（品牌色半透明）
        .followerGlassEffect(cornerRadius: 12, usesMaterial: false, fill: theme.premiumCardBackground)
    }

    /// 根据全局 index 返回对应跳转页面
    /// 注意：删除卡片会改变 index 顺序 — 同步更新此表（当前 14 项，地域分布/评论管理已移除）
    @ViewBuilder
    private func destinationFor(index: Int) -> some View {
        switch index {
        case 0: PredictionDetailView(
            predicted: viewModel.predictedFollowers,
            historical: viewModel.historyPoints,
            result: viewModel.predictionResult,
            baseFollowers: Double(viewModel.latestSnapshot?.followersCount ?? 0),
            dataDays: viewModel.predictionDataDays
        )
        case 1: ActivityDetailView(result: viewModel.activityResult)
        case 2: QualityDetailView(result: viewModel.qualityScore)
        case 3: RetentionDetailView(result: viewModel.retentionResult)
        case 4: ComparisonDetailView(result: viewModel.comparisonResult)
        case 5: UnfollowListView(followers: viewModel.unfollowList)
        case 6: BestTimeView(result: viewModel.bestPostingTimeResult)
        case 7: ContentStrategyView(aiSummary: viewModel.aiSummary.isEmpty ? viewModel.contentTip : viewModel.aiSummary)
        // Phi: 三大人群画像新 Premium 功能
        case 8: CompetitorDetailView(comparisonResult: viewModel.comparisonResult)
        case 9: AuthenticityDetailView(result: viewModel.authenticityResult)
        case 10: MediaKitDetailView(viewModel: viewModel)
        case 11: CampaignDetailView(result: viewModel.campaignResult)
        case 12: HeatmapDetailView(result: viewModel.heatmapResult)
        case 13: ContentSchedulingDetailView(activityResult: viewModel.activityResult)
        default: EmptyView()
        }
    }
}

/// Premium Tile 数据模型
private struct PremiumTileItem {
    let icon: String
    let label: String
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
        engagementHeatmapService: container.engagementHeatmapService,
        mediaPostRepository: container.mediaPostRepository,
        bestPostingTimeService: container.bestPostingTimeService,
        mediaKitService: container.mediaKitService
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
