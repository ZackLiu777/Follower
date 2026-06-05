//
//  DashboardView.swift
//  Follower
//
//  Dashboard 主页面。
//  View 只负责展示和触发交互，不得直接访问数据库。
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.accounts.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "No Account Connected",
                        message: "Connect your Instagram or TikTok account to start tracking.",
                        actionLabel: "Connect Account",
                        action: { /* Navigate to Account */ }
                    )
                } else if let snapshot = viewModel.latestSnapshot {
                    contentView(snapshot: snapshot)
                } else if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "No Data Yet",
                        message: "Sync your account to pull the latest data.",
                        actionLabel: "Sync Now",
                        action: { Task { await viewModel.sync() } }
                    )
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSyncing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await viewModel.sync() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(viewModel.selectedAccountId == nil)
                    }
                }
            }
            .refreshable {
                await viewModel.loadAccounts()
            }
        }
        .task {
            await viewModel.loadAccounts()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(snapshot: Snapshot) -> some View {
        VStack(spacing: 16) {
            accountPicker

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Followers", value: snapshot.followersCount.formatted(.number), icon: "person.2.fill", tint: .blue)
                StatCard(title: "Following", value: snapshot.followingCount.formatted(.number), icon: "person.fill.checkmark", tint: .green)
                StatCard(title: "Media", value: snapshot.mediaCount.formatted(.number), icon: "photo.stack.fill", tint: .orange)
                StatCard(title: "Engagement Rate", value: String(format: "%.1f%%", snapshot.engagementRate * 100), icon: "heart.fill", tint: .pink)
                StatCard(title: "Likes", value: snapshot.totalLikes.formatted(.number), icon: "hand.thumbsup.fill", tint: .red)
                StatCard(title: "Comments", value: snapshot.totalComments.formatted(.number), icon: "text.bubble.fill", tint: .purple)
                StatCard(title: "Shares", value: snapshot.totalShares.formatted(.number), icon: "arrowshape.turn.up.forward.fill", tint: .teal)
                StatCard(title: "Views", value: snapshot.totalViews.formatted(.number), icon: "eye.fill", tint: .indigo)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.accounts, id: \.id) { account in
                    Button {
                        if let id = account.id {
                            viewModel.selectAccount(id)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill")
                                .font(.caption)
                            Text(account.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
}

// MARK: - Preview

#Preview {
    DashboardView(viewModel: DashboardViewModel(
        snapshotRepo: PreviewMocks.snapshotRepo,
        accountRepo: PreviewMocks.accountRepo,
        syncEngine: PreviewMocks.syncEngine
    ))
    .environmentObject(AppState(databaseManager: DatabaseManager.shared))
}

// MARK: - Preview Mocks

#if DEBUG
private enum PreviewMocks {
    static let db = DatabaseManager.shared
    static let accountRepo = AccountRepository(db: db)
    static let eventRepo = EventRepository(db: db)
    static let snapshotRepo = SnapshotRepository(db: db)
    static let metricRepo = MetricRepository(db: db)
    static let aggregationService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
    static let ingestionService = IngestionService(eventRepo: eventRepo, aggregationService: aggregationService)
    static let syncEngine = SyncEngine(eventRepo: eventRepo, accountRepo: accountRepo, ingestionService: ingestionService)
}
#endif
