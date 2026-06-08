//
//  DashboardView.swift
//  Follower
//
//  Lambda: Hero粉丝 + 次要指标 + 帖子列表 + Premium Insights。

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
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
            .navigationTitle(loc(L10n.Dashboard.title))
            .toolbar { toolbar }
            .refreshable { await viewModel.loadAccounts() }
        }
        .task { await viewModel.loadAccounts() }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSyncing { ProgressView() }
            else { Button { Task { await viewModel.sync() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }.disabled(viewModel.selectedAccountId == nil) }
        }
    }

    // MARK: - Content

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

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Content").font(.headline)
                Spacer()
                if !viewModel.recentPosts.isEmpty {
                    NavigationLink("View All") { PostListView(posts: MockPostGenerator().generate(count: 20)) }
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if viewModel.recentPosts.isEmpty {
                Text("No posts yet. Sync to load content.").font(.caption).foregroundColor(.secondary).padding(.horizontal)
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

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown.fill").foregroundColor(.orange).font(.caption)
                Text("Premium Insights").font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            if appState.premiumEnabledFlags[PremiumFeatureKey.trendPrediction.rawValue] == true {
                // 解锁后：可点击的详情 NavigationLink
                VStack(spacing: 6) {
                    premiumNavRow(icon: "person.2.slash", title: "Who Unfollowed You", value: "\(viewModel.unfollowList.count) people this week", destination: UnfollowListView(followers: viewModel.unfollowList))
                    premiumNavRow(icon: "clock", title: "Best Time to Post", value: viewModel.bestPostingTime, destination: BestTimeView())
                    premiumNavRow(icon: "lightbulb", title: "Content Strategy", value: viewModel.contentTip, destination: ContentStrategyView(tip: viewModel.contentTip))
                    premiumNavRow(icon: "chart.line.uptrend.xy", title: "Follower Prediction", value: "~\(viewModel.predictedFollowers) next month", destination: PredictionDetailView(predicted: viewModel.predictedFollowers))
                }
                .padding(.horizontal)
            } else {
                // 锁定：显示锁 + 点击弹出升级
                VStack(spacing: 6) {
                    lockedRow(icon: "person.2.slash", title: "Who Unfollowed You")
                    lockedRow(icon: "clock", title: "Best Time to Post")
                    lockedRow(icon: "lightbulb", title: "Content Strategy")
                    lockedRow(icon: "chart.line.uptrend.xy", title: "Follower Prediction")
                }
                .padding(.horizontal)
                .premiumGate(feature: .trendPrediction)
            }
        }
        .padding(.vertical, 8)
    }

    private func premiumNavRow<D: View>(icon: String, title: String, value: String, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon).frame(width: 24).foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium)
                    Text(value).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func lockedRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 24).foregroundColor(.orange)
            Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            Spacer()
            Image(systemName: "lock.fill").font(.caption).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
