//
//  DashboardView.swift
//  Follower
//
//  Lambda: Hero粉丝 + 次要指标 + 帖子列表 + Premium Insights。

import SwiftUI

/// 主 Dashboard：Hero 粉丝卡片 + 次要指标 + 最近帖子 + Premium Insights 区域
struct DashboardView: View {
    @State private var appState = AppState(databaseManager: DatabaseManager.shared)
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.theme) private var theme

    /// 根布局：加载 / 空状态 / 错误 / 内容分支
    var body: some View {
        NavigationStack {
            ZStack {
                // 主题渐变背景
                LinearGradient(colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil }, onRetry: { Task { await viewModel.loadAccounts() } })
                    }
                    if viewModel.accounts.isEmpty {
                        EmptyStateView(icon: "person.crop.circle.badge.exclamationmark", title: loc(L10n.Dashboard.noAccountTitle), message: loc(L10n.Dashboard.noAccountMessage), actionLabel: loc(L10n.Dashboard.connectAccount), action: {})
                    } else if viewModel.latestSnapshot != nil {
                        contentView
                    } else if viewModel.isLoading {
                        ProgressView(loc(L10n.Common.loading)).frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        EmptyStateView(icon: "arrow.triangle.2.circlepath", title: loc(L10n.Dashboard.noDataTitle), message: loc(L10n.Dashboard.noDataMessage), actionLabel: loc(L10n.Common.syncNow), action: { Task { await viewModel.sync() } })
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(loc(L10n.Dashboard.title))
            .toolbar { toolbar }
            .refreshable { await viewModel.loadAccounts() }
        }
        .task { await viewModel.loadAccounts() }
    }

    /// 工具栏：同步按钮 / 同步中进度指示器
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSyncing { ProgressView() }
            else { Button { Task { await viewModel.sync() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }.disabled(viewModel.selectedAccountId == nil) }
        }
    }

    // MARK: - Content

    /// 主内容区：账户选择器 + Hero + 次要指标 + 帖子 + Premium
    private var contentView: some View {
        VStack(spacing: 16) {
            accountPicker

            // Hero: Followers (tappable → detail)
            NavigationLink {
                FollowerDetailView(
                    currentFollowers: viewModel.latestSnapshot?.followersCount ?? 0,
                    delta: viewModel.followerDelta, deltaPercent: viewModel.followerDeltaPercent,
                    sparklineData: viewModel.sparklineData,
                    accountName: viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountId })?.username ?? ""
                )
            } label: {
                HeroMetricCard(
                    title: loc(L10n.Dashboard.followers), value: viewModel.latestSnapshot!.followersCount.formatted(.number),
                    delta: viewModel.followerDelta, deltaPercent: viewModel.followerDeltaPercent,
                    period: "vs last 7 days", sparklineData: viewModel.sparklineData
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Secondary
            SecondaryMetricRow(
                engagementRate: viewModel.latestSnapshot?.engagementRate ?? 0,
                reach: viewModel.latestSnapshot?.totalViews ?? 0,
                posts: viewModel.latestSnapshot?.mediaCount ?? 0,
                engagementDelta: viewModel.engagementDelta,
                reachDelta: viewModel.reachDelta,
                postsDelta: viewModel.postsDelta
            )
            .padding(.horizontal)

            // Post list
            postSection

            // Premium
            premiumSection
        }
        .padding(.vertical)
    }

    /// 横向滚动账户选择器（胶囊按钮）
    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.accounts, id: \.id) { account in
                    Button { if let id = account.id { viewModel.selectAccount(id) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill").font(.caption)
                            Text(account.username).font(.subheadline).fontWeight(.medium)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(viewModel.selectedAccountId == account.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial))
                        .foregroundColor(viewModel.selectedAccountId == account.id ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Posts

    /// 最近帖子列表区域
    private var postSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(loc(L10n.Dashboard.recentContent)).font(.headline)
                Spacer()
                if !viewModel.recentPosts.isEmpty {
                    NavigationLink(loc(L10n.Dashboard.viewAll)) { PostListView(posts: MockPostGenerator().generate(count: 20)) }
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if viewModel.recentPosts.isEmpty {
                Text(loc(L10n.Dashboard.noPostsHint)).font(.caption).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentPosts) { post in
                        NavigationLink { PostDetailView(post: post) } label: {
                            PostRowView(post: post)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        if post.id != viewModel.recentPosts.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Premium

    /// Premium Insights 区域 — 解锁后展示全部 9 张分析卡片，锁定状态仅显示锁+升级入口
    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown.fill").foregroundColor(.orange).font(.caption)
                Text(loc(L10n.Premium.premiumInsights)).font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            if appState.premiumEnabledFlags[PremiumFeatureKey.trendPrediction.rawValue] == true {
                VStack(spacing: 6) {
                    // 1. Follower Prediction — 粉丝预测
                    premiumNavRow(icon: "chart.line.uptrend.xy", title: loc(L10n.Premium.followerPrediction),
                        value: viewModel.predictionResult.map { "~\(Int($0.predictedValue)) \(loc(L10n.Premium.in30Days))" } ?? loc(L10n.Premium.analyzing),
                        destination: PredictionDetailView(predicted: viewModel.predictedFollowers))

                    // 2. Activity Analysis — 活跃度分析
                    premiumNavRow(icon: "bolt.fill", title: loc(L10n.Premium.activityAnalysis),
                        value: viewModel.activityResult.map { "\($0.label) · \($0.activeDays)/\($0.totalDays) \(loc(L10n.Premium.daysActive))" } ?? loc(L10n.Premium.analyzing),
                        destination: ActivityDetailView(result: viewModel.activityResult))

                    // 3. Engagement Quality — 互动质量评分
                    premiumNavRow(icon: "star.fill", title: loc(L10n.Premium.engagementQuality),
                        value: viewModel.qualityScore.map { "Score: \(String(format: "%.1f", $0.score)) — \($0.label)" } ?? loc(L10n.Premium.analyzing),
                        destination: QualityDetailView(result: viewModel.qualityScore))

                    // 4. Retention & Churn — 留存与流失
                    premiumNavRow(icon: "person.2.fill", title: loc(L10n.Premium.retentionChurn),
                        value: viewModel.retentionResult.map { "Growth: \(String(format: "%+.1f%%", $0.netGrowthRate)) · Risk: \($0.churnRiskLevel)" } ?? loc(L10n.Premium.analyzing),
                        destination: RetentionDetailView(result: viewModel.retentionResult))

                    // 5. Geo Distribution — 粉丝地域分布
                    premiumNavRow(icon: "globe.asia.australia.fill", title: loc(L10n.Premium.geoDistribution),
                        value: viewModel.geoDistribution.map { "\($0.regions.prefix(2).map(\.name).joined(separator: ", "))" } ?? loc(L10n.Premium.analyzing),
                        destination: GeoDetailView(result: viewModel.geoDistribution))

                    // 6. Long-term Comparison — 长期趋势对比
                    premiumNavRow(icon: "arrow.left.arrow.right", title: loc(L10n.Premium.longTermComparison),
                        value: viewModel.comparisonResult.map { "\($0.direction.rawValue) · \(String(format: "%+.2f", $0.absoluteChange))" } ?? loc(L10n.Premium.analyzing),
                        destination: ComparisonDetailView(result: viewModel.comparisonResult))

                    // 7. Unfollow List — 取关列表
                    premiumNavRow(icon: "person.2.slash", title: loc(L10n.Premium.whoUnfollowedYou),
                        value: "\(viewModel.unfollowList.count) \(loc(L10n.Premium.peopleThisWeek))",
                        destination: UnfollowListView(followers: viewModel.unfollowList))

                    // 8. Best Time to Post — 最佳发帖时间
                    premiumNavRow(icon: "clock", title: loc(L10n.Premium.bestTimeToPost),
                        value: viewModel.activityResult?.mostActiveDay != nil ? "\(loc(L10n.Premium.mostActiveDay)) \(viewModel.activityResult!.mostActiveDay!)" : viewModel.bestPostingTime,
                        destination: BestTimeView())

                    // 9. Content Strategy — 内容策略
                    premiumNavRow(icon: "lightbulb", title: loc(L10n.Premium.contentStrategy),
                        value: viewModel.aiSummary.isEmpty ? viewModel.contentTip : viewModel.aiSummary,
                        destination: ContentStrategyView(tip: viewModel.contentTip))
                }
                .padding(.horizontal)
            } else {
                // 锁定状态 — 9 行全部加锁
                VStack(spacing: 6) {
                    lockedRow(icon: "chart.line.uptrend.xy", title: loc(L10n.Premium.followerPrediction))
                    lockedRow(icon: "bolt.fill", title: loc(L10n.Premium.activityAnalysis))
                    lockedRow(icon: "star.fill", title: loc(L10n.Premium.engagementQuality))
                    lockedRow(icon: "person.2.fill", title: loc(L10n.Premium.retentionChurn))
                    lockedRow(icon: "globe.asia.australia.fill", title: loc(L10n.Premium.geoDistribution))
                    lockedRow(icon: "arrow.left.arrow.right", title: loc(L10n.Premium.longTermComparison))
                    lockedRow(icon: "person.2.slash", title: loc(L10n.Premium.whoUnfollowedYou))
                    lockedRow(icon: "clock", title: loc(L10n.Premium.bestTimeToPost))
                    lockedRow(icon: "lightbulb", title: loc(L10n.Premium.contentStrategy))
                }
                .padding(.horizontal)
                .premiumGate(feature: .trendPrediction)
            }
        }
        .padding(.vertical, 8)
    }

    /// Premium 已解锁 — 可点击导航到对应详情页的行视图
    private func premiumNavRow<D: View>(icon: String, title: String, value: String, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon).frame(width: 24).foregroundColor(theme.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(theme.textPrimary)
                    Text(value).font(.caption).foregroundColor(theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(theme.textSecondary)
            }
            .padding(10)
            .background(theme.accentPrimary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Premium 锁定行 — 仅显示标题与锁图标，点击触发升级弹窗
    private func lockedRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 24).foregroundColor(theme.accentPrimary)
            Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(theme.textSecondary)
            Spacer()
            Image(systemName: "lock.fill").font(.caption).foregroundColor(theme.textSecondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
